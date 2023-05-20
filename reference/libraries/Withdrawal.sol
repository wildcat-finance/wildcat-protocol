import './VaultState.sol';
import './FeeMath.sol';

using WadRayMath for uint256;
using MathUtils for uint256;
using FeeMath for VaultState;
using SafeCastLib for uint256;

library WithdrawalBatch {
	struct FinalizedWithdrawalBatch {
		uint112 scaleFactor;
		uint104 totalScaledAmount;
		uint144 redemptionRate;
	}

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

		if (availableLiquidity >= normalizedPendingWithdrawals) {
			// there is enough liquidity to cover the entire batch
      batch.scaleFactor = state.scaleFactor;
      batch.totalScaledAmount = scaledPendingWithdrawals.safeCastTo104();
      batch.redemptionRate = 1;
      // reduce the supply by the amount withdrawn
			state.decreaseScaledTotalSupply(scaledPendingWithdrawals);
      state.nextWithdrawalExpiry = 0;
      state.scaledPendingWithdrawals = 0;
		} else {
      // there is not enough liquidity to cover the entire batch
      
    }

    if (block.timestamp > state.nextWithdrawalExpiry) {
      (uint256 feesAccruedAfterExpiry, ) = state.calculateInterestAndFees(
        block.timestamp,
        protocolFeeBips,
        penaltyFeeBips,
        gracePeriod
      );
      unchecked {
        feesAccrued += feesAccruedAfterExpiry;
      }
    }
	}
}
