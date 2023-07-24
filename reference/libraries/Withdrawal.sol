// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import './VaultState.sol';
import './FeeMath.sol';
import './Uint32Array.sol';
import '../interfaces/IVaultEventsAndErrors.sol';

using MathUtils for uint256;
using FeeMath for VaultState;
using SafeCastLib for uint256;
using WithdrawalLib for WithdrawalBatch global;
using WithdrawalLib for WithdrawalData global;

struct WithdrawalBatch {
	// Amount of scaled tokens that have been paid by borrower
	uint104 scaledPaidAmount;
	// Amount of normalized tokens that have been paid by borrower
	uint128 normalizedPaidAmount;
	// Total scaled amount of tokens to be withdrawn
	uint104 scaledTotalAmount;
}

struct AccountWithdrawalStatus {
	uint104 scaledAmount;
	uint128 lastNormalizedAmountWithdrawn;
}

struct WithdrawalData {
	Uint32Array unpaidBatches;
	mapping(uint32 => WithdrawalBatch) batches;
	mapping(uint256 => mapping(address => AccountWithdrawalStatus)) accountStatuses;
}

library WithdrawalLib {
	function processPayment(
		WithdrawalBatch storage batch,
		VaultState memory state,
		uint256 scaledAmount
	) internal {
		scaledAmount = MathUtils.min(scaledAmount, batch.scaledTotalAmount - batch.scaledPaidAmount);

		state.decreaseScaledTotalSupply(scaledAmount);
		uint256 normalizedAmount = state.normalizeAmount(scaledAmount);

		batch.scaledPaidAmount = (uint256(batch.scaledPaidAmount) + scaledAmount).safeCastTo104();
		batch.normalizedPaidAmount = (uint256(batch.normalizedPaidAmount) + normalizedAmount)
			.safeCastTo128();

		state.scaledPendingWithdrawals = (uint256(state.scaledPendingWithdrawals) - scaledAmount)
			.safeCastTo104();
		state.reservedAssets = (uint256(state.reservedAssets) + normalizedAmount).safeCastTo128();
	}

	function processNextBatch(
		WithdrawalData storage data,
		VaultState memory state,
		uint256 totalAssets
	) internal {
		if (data.unpaidBatches.isEmpty()) {
			// @todo revert
			return;
		}
		uint32 expiry = data.unpaidBatches.first();
		WithdrawalBatch storage batch = data.batches[expiry];
		uint256 availableLiquidity = totalAssets - state.reservedAssets;
		uint256 scaledAmount = state.scaleAmount(availableLiquidity);
		processPayment(batch, state, scaledAmount);
		if (batch.scaledPaidAmount == batch.scaledTotalAmount) {
			data.unpaidBatches.shift();
		}
	}

	function addWithdrawalRequest(
		WithdrawalData storage data,
		VaultState memory state,
		address account,
		uint104 scaledAmount,
		uint256 withdrawalBatchDuration
	) internal {
		uint32 expiry = state.pendingWithdrawalExpiry;
		// Create a new batch if necessary
		if (expiry == 0) {
			// @todo emit event
			expiry = uint32(block.timestamp + withdrawalBatchDuration);
			state.pendingWithdrawalExpiry = expiry;
		}
		WithdrawalBatch storage batch = data.batches[expiry];
		AccountWithdrawalStatus storage status = data.accountStatuses[expiry][account];
		// Add to account withdrawal status
		status.scaledAmount += scaledAmount;
		batch.scaledTotalAmount += scaledAmount;
		// Add to pending withdrawals
		state.scaledPendingWithdrawals += scaledAmount;
	}

	// Get amount user can withdraw now
	function withdrawableAmount(
		WithdrawalBatch memory batch,
		AccountWithdrawalStatus memory status
	) internal pure returns (uint256) {
		// Rounding errors will lead to some dust accumulating in the batch, but the cost of
		// executing a withdrawal will be lower for users.
		uint256 normalizedAmountOwed = (status.scaledAmount * batch.normalizedPaidAmount) /
			batch.scaledTotalAmount;
		return normalizedAmountOwed - status.lastNormalizedAmountWithdrawn;
	}

	function withdrawAvailable(
		WithdrawalData storage data,
		VaultState memory state,
		address account,
		uint32 expiry
	) internal returns (uint128 normalizedAmountWithdrawn) {
		WithdrawalBatch memory batch = data.batches[expiry];
		AccountWithdrawalStatus storage status = data.accountStatuses[expiry][account];
		normalizedAmountWithdrawn = withdrawableAmount(batch, status).safeCastTo128();
		status.lastNormalizedAmountWithdrawn += normalizedAmountWithdrawn;
		state.reservedAssets -= normalizedAmountWithdrawn;
	}

	function availableLiquidityForBatch(
		WithdrawalBatch memory batch,
		VaultState memory state,
		uint256 totalAssets
	) internal pure returns (uint256) {
		uint256 priorScaledAmountPending = (state.scaledPendingWithdrawals - batch.scaledTotalAmount);
		uint256 totalReservedAssets = state.reservedAssets +
			state.normalizeAmount(priorScaledAmountPending);
		return totalAssets - totalReservedAssets;
	}

	/**
	 *
	 * When a withdrawal batch expires, the vault will checkpoint the scale factor
	 * as of the time of expiry and retrieve the current liquid assets in the vault
	 * (assets which are not already owed to protocol fees or prior withdrawal batches).
	 */
	function processExpiredBatch(
		WithdrawalData storage data,
		VaultState memory state,
		uint256 totalAssets
	) internal returns (WithdrawalBatch memory) {
		WithdrawalBatch storage batch = data.batches[state.pendingWithdrawalExpiry];
		uint256 availableLiquidity = availableLiquidityForBatch(batch, state, totalAssets);

		uint104 scaledTotalAmount = batch.scaledTotalAmount;

		uint128 normalizedOwedAmount = state.normalizeAmount(scaledTotalAmount).safeCastTo128();

		(uint104 scaledPaidAmount, uint128 normalizedPaidAmount) = (availableLiquidity >=
			normalizedOwedAmount)
			? (scaledTotalAmount, normalizedOwedAmount)
			: (state.scaleAmount(availableLiquidity).safeCastTo104(), availableLiquidity.safeCastTo128());

		batch.scaledPaidAmount = scaledPaidAmount;
		batch.normalizedPaidAmount = normalizedPaidAmount;

		if (scaledPaidAmount < scaledTotalAmount) {
			data.unpaidBatches.push(state.pendingWithdrawalExpiry);
		}

		state.pendingWithdrawalExpiry = 0;
		state.reservedAssets += normalizedPaidAmount;
		state.scaledPendingWithdrawals -= scaledPaidAmount;
		state.decreaseScaledTotalSupply(scaledPaidAmount);

		return batch;
	}
}
