// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import './VaultState.sol';
import './FeeMath.sol';
import './FIFOQueue.sol';
import '../interfaces/IVaultEventsAndErrors.sol';

using MathUtils for uint256;
using FeeMath for VaultState;
using SafeCastLib for uint256;
using WithdrawalLib for WithdrawalBatch global;
using WithdrawalLib for WithdrawalData global;

/**
 * Withdrawals are grouped together in batches with a fixed expiry.
 * Until a withdrawal is paid out, the tokens are not burned from the vault
 * and continue to accumulate interest.
 */
struct WithdrawalBatch {
	// Total scaled amount of tokens to be withdrawn
	uint104 scaledTotalAmount;
	// Amount of scaled tokens that have been paid by borrower
	uint104 scaledAmountBurned;
	// Amount of normalized tokens that have been paid by borrower
	uint128 normalizedAmountPaid;
}

struct AccountWithdrawalStatus {
	uint104 scaledAmount;
	uint128 normalizedAmountWithdrawn;
}

struct WithdrawalData {
	FIFOQueue unpaidBatches;
	mapping(uint32 => WithdrawalBatch) batches;
	mapping(uint256 => mapping(address => AccountWithdrawalStatus)) accountStatuses;
}

library WithdrawalLib {
	event WithdrawalBatchExpired(
		uint256 expiry,
		uint256 scaledTotalAmount,
		uint256 scaledAmountBurned,
		uint256 normalizedAmountPaid
	);
	event WithdrawalBatchCreated(uint256 expiry);
	event WithdrawalQueued(uint256 expiry, address account, uint256 scaledAmount);

	function addWithdrawalRequest(
		WithdrawalData storage data,
		VaultState memory state,
		address account,
		uint104 scaledAmount,
		uint256 withdrawalBatchDuration
	) internal {
		// Note: Always executed after interest is accrued and expired batches are processed.
		uint32 expiry = state.pendingWithdrawalExpiry;

		// Create a new batch if necessary
		if (expiry == 0) {
			expiry = uint32(block.timestamp + withdrawalBatchDuration);
			state.pendingWithdrawalExpiry = expiry;
			emit WithdrawalBatchCreated(expiry);
		}

		WithdrawalBatch storage batch = data.batches[expiry];
		AccountWithdrawalStatus storage status = data.accountStatuses[expiry][account];

		// Add to account withdrawal status
		status.scaledAmount += scaledAmount;
		batch.scaledTotalAmount += scaledAmount;

		// Add to pending withdrawals
		state.scaledPendingWithdrawals += scaledAmount;

		emit WithdrawalQueued(
			uint256(state.pendingWithdrawalExpiry),
			address(msg.sender),
			uint256(scaledAmount)
		);
	}

	// Get amount user can withdraw now
	// function withdrawableAmount(
	// 	WithdrawalBatch memory batch,
	// 	AccountWithdrawalStatus memory status
	// ) internal pure returns (uint256) {
	// 	// Rounding errors will lead to some dust accumulating in the batch, but the cost of
	// 	// executing a withdrawal will be lower for users.
	// 	uint256 normalizedTotalAmountPaid = (status.scaledAmount * batch.normalizedAmountPaid) /
	// 		batch.scaledTotalAmount;
	//   uint104 scaledAmountBurned = (status.scaledAmount * batch.scaledAmountBurned) / batch.scaledTotalAmount;
	// 	return normalizedTotalAmountPaid - status.lastNormalizedAmountWithdrawn;
	// }

	function withdrawAvailable(
		WithdrawalData storage data,
		VaultState memory state,
		address account,
		uint32 expiry
	) internal returns (uint128 normalizedAmountWithdrawn) {
		WithdrawalBatch memory batch = data.batches[expiry];
		AccountWithdrawalStatus storage status = data.accountStatuses[expiry][account];

		normalizedAmountWithdrawn = (uint256(batch.normalizedAmountPaid).mulDiv(
			status.scaledAmount,
			batch.scaledTotalAmount
		) - status.normalizedAmountWithdrawn).toUint128();

		status.normalizedAmountWithdrawn += normalizedAmountWithdrawn;
		state.reservedAssets -= normalizedAmountWithdrawn;
	}

	/**
	 * @dev Get the amount of assets which are not already reserved
	 *      for prior withdrawal batches.
	 */
	function availableLiquidityForBatch(
		WithdrawalBatch memory batch,
		VaultState memory state,
		uint256 totalAssets
	) internal pure returns (uint256) {
		// Prior withdrawal batches take priority, so the normalized value of prior batches
		// is subtracted from the total assets to calculate liquidity available for the batch.
		uint256 priorScaledAmountPending = (state.scaledPendingWithdrawals - batch.scaledTotalAmount);
		uint256 totalReservedAssets = state.reservedAssets +
			state.normalizeAmount(priorScaledAmountPending) +
			state.accruedProtocolFees;
		return totalAssets - totalReservedAssets;
	}
}

/*
Invariants:
scaledPendingWithdrawals = sum of scaled amounts in withdrawal requests minus sum of scaled tokens burned in withdrawal payments



processExpiredBatch

Scenarios

-- Sufficient collateral
1. scaledPendingWithdrawals reduced by scaledTotalAmount
2. scaledTotalSupply reduced by scaledTotalAmount
3. scaledAmountBurned = scaledTotalAmount
4. normalizedAmountPaid = normalize(scaledTotalAmount)



Alternative:
Users immediately burn their tokens when making a withdrawal request.
This would allow us to avoid the complexity of the withdrawal queue.
The normalized amount of the withdrawal would be added directly to the required collateral.
Users' withdrawal data maps only normalized amounts, not scaled amounts.
Borrower still pays for penalties on late withdrawals

*/
