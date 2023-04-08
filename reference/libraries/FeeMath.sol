// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './math/MathUtils.sol';
import './SafeCastLib.sol';
import './VaultState.sol';
import './math/WadRayMath.sol';

// using Math for uint256;
using WadRayMath for uint256;
using SafeCastLib for uint256;
using MathUtils for uint256;

library FeeMath {
	/**
	 * @dev Calculates interest and protocol fees accrued since last state update. and applies it to
	 * cached state returns protocol fees accrued.
	 *
	 * @param state Vault scale parameters
	 * @param protocolFeeBips Protocol fee on interest
	 * @param penaltyFeeBips Fee for delinquency in excess of gracePeriod
	 * @param gracePeriod Maximum time in delinquency before penalties are applied
	 * @return feesAccrued Protocol fees owed on interest
	 * @return didUpdate Whether interest has accrued since last update
	 */
	function calculateInterestAndFees(
		VaultState memory state,
		uint256 protocolFeeBips,
		uint256 penaltyFeeBips,
		uint256 gracePeriod
	) internal view returns (uint256 feesAccrued, bool didUpdate) {
		uint256 scaleFactor = state.scaleFactor;
		uint256 lastInterestAccruedTimestamp = state.lastInterestAccruedTimestamp;

		uint256 timeDelta = lastInterestAccruedTimestamp.timeElapsedSince();
		didUpdate = timeDelta > 0;

		// If time has passed since last update, calculate interest and fees accrued.
		if (didUpdate) {
			// Calculate base growth in the scale factor from the pool's interest rate.
			uint256 interestAccruedRay = MathUtils.calculateLinearInterestFromBips(
				state.annualInterestBips,
				timeDelta
			);

			if (protocolFeeBips > 0) {
				// Protocol fee is taken from the vault's interest rate.
				uint256 protocolFeeRay = protocolFeeBips.bipMul(interestAccruedRay);

				// Unchecked because protocolFeeBips can not exceed BIP, so
				// interestAccruedRay can not underflow.
				unchecked {
					interestAccruedRay -= protocolFeeRay;
				}

				// Calculate fees accrued to protocol
				feesAccrued = uint256(state.scaledTotalSupply).rayMul(
          scaleFactor.rayMul(protocolFeeRay)
        );
			}

			if (penaltyFeeBips > 0) {
				// Calculate the number of seconds the borrower spent in penalized
				// delinquency since the last update.
				uint256 timeWithPenalty = updateTimeDelinquentAndGetPenaltyTime(
					state,
					gracePeriod,
					timeDelta
				);

				if (timeWithPenalty > 0) {
					// Apply penalty fees to the interest accrued.
					interestAccruedRay += MathUtils.calculateLinearInterestFromBips(
						penaltyFeeBips,
						timeWithPenalty
					);
				}
			}

			// Calculate new scaleFactor
			uint256 scaleFactorDelta = scaleFactor.rayMul(interestAccruedRay);

			// Update scaleFactor and timestamp
			state.scaleFactor = (scaleFactor + scaleFactorDelta).safeCastTo112();
			state.lastInterestAccruedTimestamp = uint32(block.timestamp);
		}

		return (feesAccrued, didUpdate);
	}

	/**
	 * @notice  Calculate the number of seconds that the vault has been in
	 *          penalized delinquency since the last update, and update
	 *          `timeDelinquent` in state.
	 *
	 * @dev When `isDelinquent`, equivalent to:
	 *        max(0, timeDelta - max(0, gracePeriod - previousTimeDelinquent))
	 *      When `!isDelinquent`, equivalent to:
	 *        min(timeDelta, max(0, previousTimeDelinquent - gracePeriod))
	 *
	 * @param state Encoded state parameters
	 * @param gracePeriod Seconds in delinquency before penalties apply
	 * @param timeDelta Seconds since the last update
	 * @param `timeWithPenalty` Number of seconds since the last update where
	 *        the vault was in delinquency outside of the grace period.
	 */
	function updateTimeDelinquentAndGetPenaltyTime(
		VaultState memory state,
		uint256 gracePeriod,
		uint256 timeDelta
	) internal pure returns (uint256 /* timeWithPenalty */) {
		// Seconds in delinquency at last update
		uint256 previousTimeDelinquent = state.timeDelinquent;

		if (state.isDelinquent) {
			// Since the borrower is still delinquent, increase the total
			// time in delinquency by the time elapsed.
			state.timeDelinquent = (previousTimeDelinquent + timeDelta)
				.safeCastTo32();

			// Calculate the number of seconds the borrower had remaining
			// in the grace period.
			uint256 secondsRemainingWithoutPenalty = gracePeriod.satSub(
				previousTimeDelinquent
			);

			// Penalties apply for the number of seconds the vault spent in
			// delinquency outside of the grace period since the last update.
			return timeDelta.satSub(secondsRemainingWithoutPenalty);
		}

		// Reduce the total time in delinquency by the time elapsed, stopping
		// when it reaches zero.
		state.timeDelinquent = previousTimeDelinquent
			.satSub(timeDelta)
			.safeCastTo32();

		// Calculate the number of seconds the old timeDelinquent had remaining
		// outside the grace period, or zero if it was already in the grace period.
		uint256 secondsRemainingWithPenalty = previousTimeDelinquent.satSub(
			gracePeriod
		);

		// Only apply penalties for the remaining time outside of the grace period.
		return MathUtils.min(secondsRemainingWithPenalty, timeDelta);
	}
}

// /**
//  * @dev Calculate the new total time in delinquency and the time
//  * outside of the grace period since the last update.
//  * @param state Encoded state parameters
//  * @param timeElapsed Time since last update
//  * @param gracePeriod Threshold before delinquency incurs penalties
//  * @return timeWithPenalty Seconds since last update where penalties applied
//  */
// function _calculateDelinquencyTime(
// 	VaultState memory state,
// 	uint256 timeElapsed,
// 	uint256 gracePeriod
// ) pure returns (uint256 timeWithPenalty) {
// 	bool isDelinquent = state.isDelinquent;
// 	uint256 timeDelinquent = state.timeDelinquent;

// 	uint256 previousTimeDelinquent = state.timeDelinquent;

// 	if (isDelinquent) {
// 		state.timeDelinquent = (timeDelinquent + timeElapsed).safeCastTo32();

// 		// Get the number of seconds the old timeDelinquent was from exceeding
// 		// the grace period, or zero if it was already past the grace period.
// 		uint256 secondsWithoutPenalty = gracePeriod.satSub(
// 			previousTimeDelinquent
// 		);

// 		/*  max(elapsed - max(gracePeriod - timeDelinquent, 0), 0) */
// 		// Subtract the remainder of the grace period from the time elapsed
// 		timeWithPenalty = uint256(timeElapsed).satSub(secondsWithoutPenalty);
// 	} else {
// 		// Get the number of seconds the old timeDelinquent had remaining
// 		// in the grace period, or zero if it was already in the grace period.
// 		uint256 secondsWithPenalty = timeDelinquent.satSub(gracePeriod);
// 		// The time with penalty in the last interval is the min of:
// 		// timeDelinquent - gracePeriod, timeElapsed, 0
// 		timeWithPenalty = Math.min(secondsWithPenalty, timeElapsed);
// 		// Reduce `timeDelinquent` by time elapsed until it hits zero
// 		state.timeDelinquent = timeDelinquent
// 			.satSub(timeElapsed)
// 			.safeCastTo32();

// 		/* min(timeElapsed, max(timeDelinquent - gracePeriod, 0)) */
// 	}
// }
