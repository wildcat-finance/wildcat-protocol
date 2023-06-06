// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import './VaultState.sol';
import './FeeMath.sol';

using WadRayMath for uint256;
using MathUtils for uint256;
using FeeMath for VaultState;
using SafeCastLib for uint256;

library WithdrawalBatch {
	struct FinalizedWithdrawalBatch {
		// Scale factor at the time of expiry
		// uint112 scaleFactor;

		// Amount of scaled tokens left in the withdrawal batch.
		// Stored as the total amount of scaled tokens in the batch, rather
		// than the amount of scaled tokens which are actually withdrawable,
		// to minimize rounding errors.
		// Decremented as each account makes a withdrawal.
		uint104 totalScaledAmount;
		//
		uint128 totalNormalizedAmount;
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
	function handleWithdrawalBatchExpiry(
		VaultState memory state,
		uint256 batchDuration,
		uint256 availableLiquidity,
		uint256 protocolFeeBips,
		uint256 penaltyFeeBips,
		uint256 gracePeriod
	) internal view returns (FinalizedWithdrawalBatch memory batch, uint256 feesAccrued) {
		(feesAccrued, ) = state.calculateInterestAndFees(
			state.nextWithdrawalExpiry,
			protocolFeeBips,
			penaltyFeeBips,
			gracePeriod
		);

		// uint256 withdrawalId = state.nextWithdrawalExpiry / batchDuration;
		uint256 scaledPendingWithdrawals = state.scaledPendingWithdrawals;
		uint256 normalizedPendingWithdrawals = state.normalizeAmount(scaledPendingWithdrawals);

		// batch.scaleFactor = state.scaleFactor;
		batch.totalScaledAmount = scaledPendingWithdrawals.safeCastTo104();

		if (availableLiquidity >= normalizedPendingWithdrawals) {
			batch.totalNormalizedAmount = normalizedPendingWithdrawals.safeCastTo128();
			// there is enough liquidity to cover the entire batch
			batch.redemptionRate = RAY.safeCastTo144();
			// reduce the supply by the amount withdrawn
			state.decreaseScaledTotalSupply(scaledPendingWithdrawals);
			state.nextWithdrawalExpiry = 0;
			state.scaledPendingWithdrawals = 0;
		} else {
			// there is not enough liquidity to cover the entire batch
			uint256 redemptionRate = availableLiquidity.rayDiv(normalizedPendingWithdrawals);
			batch.totalNormalizedAmount = availableLiquidity.safeCastTo128();
			batch.redemptionRate = redemptionRate.safeCastTo144();
			uint256 scaledWithdrawnAmount = redemptionRate.rayMul(scaledPendingWithdrawals);
			// reduce the supply by the amount withdrawn
			state.decreaseScaledTotalSupply(scaledWithdrawnAmount);
			// set the remainder as the new pending withdrawal amount
			state.scaledPendingWithdrawals = (scaledPendingWithdrawals - scaledWithdrawnAmount)
				.safeCastTo104();
			// reset the withdrawal batch expiry
			state.nextWithdrawalExpiry = (block.timestamp + batchDuration).safeCastTo32();
		}

		if (block.timestamp > state.nextWithdrawalExpiry) {
			(uint256 feesAccruedAfterExpiry, ) = state.calculateInterestAndFees(
				block.timestamp,
				protocolFeeBips,
				penaltyFeeBips,
				gracePeriod
			);
			feesAccrued += feesAccruedAfterExpiry;
		}
	}

	function finalizeWithdrawal(
		VaultState memory state,
		FinalizedWithdrawalBatch memory batch,
		PendingAccountWithdrawal memory withdrawal
	) internal pure returns (uint256 amount) {
		uint256 originalScaledAmount = withdrawal.scaledAmount;
		uint256 fraction = originalScaledAmount.rayDiv(batch.totalScaledAmount);

		amount = uint256(batch.totalNormalizedAmount).rayMul(fraction);
		batch.totalNormalizedAmount -= amount.safeCastTo128();

		// Reduce the total scaled amount by the amount withdrawn
		uint256 scaledAmount = originalScaledAmount.rayMul(batch.redemptionRate);
		batch.totalScaledAmount -= scaledAmount.safeCastTo104();

		// Reduce the supply by the amount withdrawn
		state.decreaseScaledTotalSupply(scaledAmount);

		// If the withdrawal is incomplete, reset the withdrawal batch expiry
		if (batch.redemptionRate < RAY) {
			withdrawal.expiry = state.nextWithdrawalExpiry;
			withdrawal.scaledAmount = (originalScaledAmount - scaledAmount).safeCastTo104();
		} else {
			withdrawal.expiry = 0;
			withdrawal.scaledAmount = 0;
		}
	}
}
