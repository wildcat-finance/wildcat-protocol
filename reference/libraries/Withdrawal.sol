// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import './VaultState.sol';
import './FeeMath.sol';

using MathUtils for uint256;
using FeeMath for VaultState;
using SafeCastLib for uint256;
using WithdrawalLib for WithdrawalBatch global;

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

library WithdrawalLib {
	// Get batch amount owed
	function owedAmount(
		WithdrawalBatch memory batch,
		VaultState memory state
	) internal pure returns (uint256) {
		// Normalize unpaid amount with current scaleFactor, since pending withdrawals accrue interest
		return state.normalizeAmount(batch.scaledTotalAmount - batch.scaledPaidAmount);
	}

	// Get total underlying value of withdrawal batch
	function totalNormalizedAmount(
		WithdrawalBatch memory batch,
		VaultState memory state
	) internal pure returns (uint256) {
		return batch.normalizedPaidAmount + batch.owedAmount(state);
	}

	function processPayment(
		VaultState memory state,
		WithdrawalBatch memory batch,
		uint256 scaledAmount
	) internal pure {
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

	// Get amount user can withdraw now
	function withdrawableAmount(
		WithdrawalBatch memory batch,
		AccountWithdrawalStatus memory account
	) internal pure returns (uint256) {
		// Rounding errors will lead to some dust accumulating in the batch, but the cost of
		// executing a withdrawal will be lower for users.
		uint256 normalizedAmountOwed = (account.scaledAmount * batch.normalizedPaidAmount) /
			batch.scaledTotalAmount;
		return account.lastNormalizedAmountWithdrawn - normalizedAmountOwed;
	}

	function withdrawAvailable(
		VaultState memory state,
		WithdrawalBatch memory batch,
		AccountWithdrawalStatus memory status
	) internal pure returns (uint128 normalizedAmountWithdrawn) {
		normalizedAmountWithdrawn = withdrawableAmount(batch, status).safeCastTo128();
		status.lastNormalizedAmountWithdrawn += normalizedAmountWithdrawn;
		state.reservedAssets -= normalizedAmountWithdrawn;
	}

	/**
	 * When a withdrawal batch expires, the vault will checkpoint the scale factor
	 * as of the time of expiry and retrieve the current liquid assets in the vault
	 * (assets which are not already owed to protocol fees or prior withdrawal batches).
	 */
	function processExpiredBatch(
		VaultState memory state,
    mapping(uint256 => WithdrawalBatch) storage batches,
		uint256 availableLiquidity
	) internal returns (WithdrawalBatch memory) {
    WithdrawalBatch storage batch = batches[state.pendingWithdrawalExpiry];

		uint104 scaledTotalAmount = batch.scaledTotalAmount;

		uint128 normalizedOwedAmount = state.normalizeAmount(scaledTotalAmount).safeCastTo128();

		(uint104 scaledPaidAmount, uint128 normalizedPaidAmount) = (availableLiquidity >=
			normalizedOwedAmount)
			? (scaledTotalAmount, normalizedOwedAmount)
			: (state.scaleAmount(availableLiquidity).safeCastTo104(), availableLiquidity.safeCastTo128());

		batch.scaledPaidAmount = scaledPaidAmount;
		batch.normalizedPaidAmount = normalizedPaidAmount;

    state.pendingWithdrawalExpiry = 0;
		state.reservedAssets += normalizedPaidAmount;
		state.scaledPendingWithdrawals -= scaledPaidAmount;
		state.decreaseScaledTotalSupply(scaledPaidAmount);

    return batch;
	}

	/*
  scaleFactor should grow until full owed amount is deposited
  can calculate current debt with
  if withdrawals still accrue interest, easy way to game the system, albeit with no
  real benefit to the user

  struct WithdrawalBatch {
    uint104 scaledTotalAmount;
    uint104 scaledPaidAmount;
    uint128 normalizedPaidAmount;
  }

  struct AccountWithdrawalStatus {
    uint104 scaledAmount;
    uint104 lastScaledAmountWithdrawn;
  }

  // Get batch amount owed
  function owedAmount(WithdrawalBatch memory batch) internal pure returns (uint256) {
    // Normalize unpaid amount with current scaleFactor, since pending withdrawals accrue interest
    return state.normalizeAmount(batch.scaledTotalAmount - batch.scaledPaidAmount);
  }

  // Get total underlying value of withdrawal batch
  function totalNormalizedAmount(WithdrawalBatch memory batch) internal pure returns (uint256) {
    return batch.normalizedPaidAmount + batch.owedAmount();
  }

  function repayAmount(VaultState memory state, WithdrawalBatch memory batch, uint256 scaledAmount) internal pure {
    batch.scaledPaidAmount += scaledAmount;
    state.decreaseScaledTotalSupply(scaledAmount);
    uint256 normalizedAmount = state.normalizeAmount(scaledAmount);
    state.pendingScaledWithdrawals -= scaledAmount;
    state.reservedAssets += normalizedAmount;
    batch.normalizedPaidAmount += normalizedAmount;
  }

  // Get amount user can withdraw now
  function withdrawableAmount(WithdrawalBatch memory batch, AccountWithdrawalStatus memory account) internal pure returns (uint256) {
    // Rounding errors will lead to some dust accumulating in the batch, but the cost of
    // executing a withdrawal will be lower for users.
    uint256 normalizedAmountOwed = (account.scaledAmount * batch.normalizedPaidAmount) / batch.scaledTotalAmount;
    return account.normalizedAmountOwed - account.lastNormalizedAmountWithdrawn;
  }

  function finalizeWithdrawal(VaultState memory state, WithdrawalBatch memory batch, AccountWithdrawalStatus memory account) internal {
    uint256 normalizedAmountWithdrawable = withdrawableAmount(batch, account);
    account.lastNormalizedAmountWithdrawn += normalizedAmountWithdrawable;
    state.reservedAssets -= normalizedAmountWithdrawable;
  }

  // Get user amount owed
  scaleFactor = batch.finished() ? batch.scaleFactor : state.scaleFactor;
  
  normalizedAmountOwed = userBatch.scaledAmount * scaleFactor;

  state.scaleFactor * (batch.scaledAmountDeposited 
*/

	// function handleWithdrawalBatchExpiry(
	// 	VaultState memory state,
	// 	uint256 batchDuration,
	// 	uint256 availableLiquidity,
	// 	uint256 protocolFeeBips,
	// 	uint256 delinquencyFeeBips,
	// 	uint256 delinquencyGracePeriod
	// ) internal view returns (WithdrawalBatch memory batch, uint256 protocolFee) {
	// 	(, ,  protocolFee) = state.updateScaleFactor(
	// 		state.pendingWithdrawalExpiry,
	// 		protocolFeeBips,
	// 		delinquencyFeeBips,
	// 		delinquencyGracePeriod
	// 	);

	// 	uint256 scaledPendingWithdrawals = state.scaledPendingWithdrawals;
	// 	uint256 normalizedPendingWithdrawals = state.normalizeAmount(scaledPendingWithdrawals);

	// 	batch.scaledTotalAmount = scaledPendingWithdrawals.safeCastTo104();

	// 	if (availableLiquidity >= normalizedPendingWithdrawals) {
	// 		batch.normalizedRedeemedAmount = normalizedPendingWithdrawals.safeCastTo128();
	// 		// there is enough liquidity to cover the entire batch
	// 		batch.redemptionRate = RAY.safeCastTo144();
	// 		// reduce the supply by the amount withdrawn
	// 		state.decreaseScaledTotalSupply(scaledPendingWithdrawals);
	// 		state.pendingWithdrawalExpiry = 0;
	// 		state.scaledPendingWithdrawals = 0;
	// 	} else {
	// 		// there is not enough liquidity to cover the entire batch
	// 		uint256 redemptionRate = availableLiquidity.rayDiv(normalizedPendingWithdrawals);
	// 		batch.normalizedRedeemedAmount = availableLiquidity.safeCastTo128();
	// 		batch.redemptionRate = redemptionRate.safeCastTo144();
	// 		uint256 scaledWithdrawnAmount = redemptionRate.rayMul(scaledPendingWithdrawals);
	// 		// reduce the supply by the amount withdrawn
	// 		state.decreaseScaledTotalSupply(scaledWithdrawnAmount);
	// 		// set the remainder as the new pending withdrawal amount
	// 		state.scaledPendingWithdrawals = (scaledPendingWithdrawals - scaledWithdrawnAmount)
	// 			.safeCastTo104();
	// 		// reset the withdrawal batch expiry
	// 		state.pendingWithdrawalExpiry = (block.timestamp + batchDuration).safeCastTo32();
	// 	}

	// 	if (block.timestamp > state.pendingWithdrawalExpiry) {
	// 		(uint256 feesAccruedAfterExpiry, ) = state.updateScaleFactor(
	// 			block.timestamp,
	// 			protocolFeeBips,
	// 			delinquencyFeeBips,
	// 			delinquencyGracePeriod
	// 		);
	// 		feesAccrued += feesAccruedAfterExpiry;
	// 	}
	// }
}

/*

We want to be able to keep accurate accounting for amounts in finalized withdrawals.

When a batch is finalized, it's easy to figure out the scale factor for it as of expiry and save that
with the normalized amount, then create a new batch for the remainder.
However, when we process the same for a user, we need to be able to map that user's withdrawal to the
correct future batch, and we need to be able to do that without iterating over all the batches.
As soon as any batch 



On user withdrawal:
- Reduce balance by scaled withdrawal amount
- Add scaled withdrawal amount to scaled pending withdrawals
- If there is no pending withdrawal batch, set the next withdrawal expiry to the current time + batch duration

On withdrawal batch expiry:


*/
