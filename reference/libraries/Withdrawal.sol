// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import './VaultState.sol';
import './FeeMath.sol';

using MathUtils for uint256;
using FeeMath for VaultState;
using SafeCastLib for uint256;

library WithdrawalBatch {
  using FeeMath for VaultState;
	struct ExpiredBatch {
		// Scale factor at the time of expiry
		// uint112 scaleFactor;

		// Amount of scaled tokens left in the withdrawal batch.
		// Stored as the total amount of scaled tokens in the batch, rather
		// than the amount of scaled tokens which are actually withdrawable,
		// to minimize rounding errors.
		// Decremented as each account makes a withdrawal.
		uint104 totalScaledAmount;
		//
		uint128 normalizedRedeemedAmount;
		// Fraction of the withdrawal batch that is redeemable
		uint144 redemptionRate;
	}

	struct PendingAccountWithdrawal {
		uint104 scaledAmount;
		uint32 expiry;
	}



	/**
   * When a withdrawal batch expires, the vault will checkpoint the scale factor
   * as of the time of expiry and retrieve the current liquid assets in the vault
   * (assets which are not already owed to protocol fees or prior withdrawal batches).
   * If the vault has insufficient assets:

   */
  function processExpiredBatch(
    VaultState memory state,
    uint256 batchDuration,
    uint256 availableLiquidity
  ) internal view returns (ExpiredBatch memory batch) {
    uint256 scaledPendingWithdrawals = state.scaledPendingWithdrawals;
		uint256 normalizedPendingWithdrawals = state.normalizeAmount(scaledPendingWithdrawals);

		batch.totalScaledAmount = scaledPendingWithdrawals.safeCastTo104();

		if (availableLiquidity >= normalizedPendingWithdrawals) {
			batch.normalizedRedeemedAmount = normalizedPendingWithdrawals.safeCastTo128();
			// there is enough liquidity to cover the entire batch
			batch.redemptionRate = RAY.safeCastTo144();
			// reduce the supply by the amount withdrawn
			state.decreaseScaledTotalSupply(scaledPendingWithdrawals);
			state.pendingWithdrawalExpiry = 0;
			state.scaledPendingWithdrawals = 0;
      state.reservedAssets = uint256(state.reservedAssets).satSub(normalizedPendingWithdrawals).safeCastTo128();
		} else {
			// there is not enough liquidity to cover the entire batch
			uint256 redemptionRate = availableLiquidity.rayDiv(normalizedPendingWithdrawals);
			batch.normalizedRedeemedAmount = availableLiquidity.safeCastTo128();
			batch.redemptionRate = redemptionRate.safeCastTo144();
			uint256 scaledWithdrawnAmount = redemptionRate.rayMul(scaledPendingWithdrawals);
			// reduce the supply by the amount withdrawn
			state.decreaseScaledTotalSupply(scaledWithdrawnAmount);
			// set the remainder as the new pending withdrawal amount
			state.scaledPendingWithdrawals = (scaledPendingWithdrawals - scaledWithdrawnAmount)
				.safeCastTo104();
			// reset the withdrawal batch expiry
			state.pendingWithdrawalExpiry = (block.timestamp + batchDuration).safeCastTo32();
      state.reservedAssets = uint256(state.reservedAssets).satSub(availableLiquidity).safeCastTo128();
		}
  }

	// function handleWithdrawalBatchExpiry(
	// 	VaultState memory state,
	// 	uint256 batchDuration,
	// 	uint256 availableLiquidity,
	// 	uint256 protocolFeeBips,
	// 	uint256 delinquencyFeeBips,
	// 	uint256 delinquencyGracePeriod
	// ) internal view returns (ExpiredBatch memory batch, uint256 protocolFee) {
	// 	(, ,  protocolFee) = state.updateScaleFactor(
	// 		state.pendingWithdrawalExpiry,
	// 		protocolFeeBips,
	// 		delinquencyFeeBips,
	// 		delinquencyGracePeriod
	// 	);

	// 	uint256 scaledPendingWithdrawals = state.scaledPendingWithdrawals;
	// 	uint256 normalizedPendingWithdrawals = state.normalizeAmount(scaledPendingWithdrawals);

	// 	batch.totalScaledAmount = scaledPendingWithdrawals.safeCastTo104();

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

	function finalizeWithdrawal(
		VaultState memory state,
		PendingAccountWithdrawal memory withdrawal,
		mapping(uint256 /* expiry */ => ExpiredBatch) storage withdrawalBatches
	) internal view returns (uint256 amount) {
		ExpiredBatch memory batch = withdrawalBatches[withdrawal.expiry];
		uint256 originalScaledAmount = withdrawal.scaledAmount;

		// Fraction of total withdrawal requests that this withdrawal represents
		uint256 fraction = originalScaledAmount.rayDiv(batch.totalScaledAmount);

		// Amount of total assets available for the withdrawal batch
		amount = uint256(batch.normalizedRedeemedAmount).rayMul(fraction);
		batch.normalizedRedeemedAmount -= amount.safeCastTo128();

		// Reduce the total scaled amount by the amount withdrawn
		batch.totalScaledAmount -= originalScaledAmount.safeCastTo104();

		// If the withdrawal is incomplete, add the remainder to the current
    // withdrawal batch and scale the amount down by the redemption rate.
		if (batch.redemptionRate < RAY) {
			withdrawal.expiry = state.pendingWithdrawalExpiry;
      uint256 scaledAmountWithdrawn = originalScaledAmount.rayMul(batch.redemptionRate);
			withdrawal.scaledAmount = (originalScaledAmount - scaledAmountWithdrawn).safeCastTo104();
		} else {
			withdrawal.expiry = 0;
			withdrawal.scaledAmount = 0;
		}
    state.reservedAssets = uint256(state.reservedAssets).satSub(amount).safeCastTo128();
	}
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
