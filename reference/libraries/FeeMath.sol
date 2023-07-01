// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './MathUtils.sol';
import './SafeCastLib.sol';
import './VaultState.sol';

// using Math for uint256;
using SafeCastLib for uint256;
using MathUtils for uint256;

library FeeMath {
	/**
	 * @dev Function to calculate the interest accumulated using a linear interest rate formula
	 *
	 * @param rateBip The interest rate, in bips
	 * @param timeDelta The time elapsed since the last interest accrual
	 * @return result The interest rate linearly accumulated during the timeDelta, in ray
	 */
	function calculateLinearInterestFromBips(
		uint256 rateBip,
		uint256 timeDelta
	) internal pure returns (uint256 result) {
		uint256 rate = rateBip.bipToRay();
		uint256 accumulatedInterestRay = rate * timeDelta;
		unchecked {
			return accumulatedInterestRay / SECONDS_IN_365_DAYS;
		}
	}

	function calculateBaseInterest(
		VaultState memory state,
		uint256 timestamp
	) internal pure returns (uint256 baseInterestRay) {
		baseInterestRay = MathUtils.calculateLinearInterestFromBips(
			state.annualInterestBips,
			timestamp - state.lastInterestAccruedTimestamp
		);
	}

	function applyProtocolFee(
		VaultState memory state,
		uint256 baseInterestRay,
		uint256 protocolFeeBips
	) internal pure returns (uint256 protocolFee) {
		// Protocol fee is charged in addition to the interest paid to lenders.
		// It is not applied to the scale factor.
		uint256 protocolFeeRay = protocolFeeBips.bipMul(baseInterestRay);
		protocolFee = uint256(state.scaledTotalSupply).rayMul(
			uint256(state.scaleFactor).rayMul(protocolFeeRay)
		);
    state.accruedProtocolFees = (state.accruedProtocolFees + protocolFee).safeCastTo128();
	}

	function updateDelinquency(
		VaultState memory state,
		uint256 timestamp,
		uint256 delinquencyFeeBips,
		uint256 delinquencyGracePeriod
	) internal pure returns (uint256 penaltyFee) {
		// Calculate the number of seconds the borrower spent in penalized
		// delinquency since the last update.
		uint256 timeWithPenalty = updateTimeDelinquentAndGetPenaltyTime(
			state,
			delinquencyGracePeriod,
			timestamp - state.lastInterestAccruedTimestamp
		);

		if (timeWithPenalty > 0) {
			// Calculate penalty fees on the interest accrued.
			penaltyFee = calculateLinearInterestFromBips(delinquencyFeeBips, timeWithPenalty);
		}
	}

	/**
	 * @notice  Calculate the number of seconds that the vault has been in
	 *          penalized delinquency since the last update, and update
	 *          `timeDelinquent` in state.
	 *
	 * @dev When `isDelinquent`, equivalent to:
	 *        max(0, timeDelta - max(0, delinquencyGracePeriod - previousTimeDelinquent))
	 *      When `!isDelinquent`, equivalent to:
	 *        min(timeDelta, max(0, previousTimeDelinquent - delinquencyGracePeriod))
	 *
	 * @param state Encoded state parameters
	 * @param delinquencyGracePeriod Seconds in delinquency before penalties apply
	 * @param timeDelta Seconds since the last update
	 * @param `timeWithPenalty` Number of seconds since the last update where
	 *        the vault was in delinquency outside of the grace period.
	 */
	function updateTimeDelinquentAndGetPenaltyTime(
		VaultState memory state,
		uint256 delinquencyGracePeriod,
		uint256 timeDelta
	) internal pure returns (uint256 /* timeWithPenalty */) {
		// Seconds in delinquency at last update
		uint256 previousTimeDelinquent = state.timeDelinquent;

		if (state.isDelinquent) {
			// Since the borrower is still delinquent, increase the total
			// time in delinquency by the time elapsed.
			state.timeDelinquent = (previousTimeDelinquent + timeDelta).safeCastTo32();

			// Calculate the number of seconds the borrower had remaining
			// in the grace period.
			uint256 secondsRemainingWithoutPenalty = delinquencyGracePeriod.satSub(
				previousTimeDelinquent
			);

			// Penalties apply for the number of seconds the vault spent in
			// delinquency outside of the grace period since the last update.
			return timeDelta.satSub(secondsRemainingWithoutPenalty);
		}

		// Reduce the total time in delinquency by the time elapsed, stopping
		// when it reaches zero.
		state.timeDelinquent = previousTimeDelinquent.satSub(timeDelta).safeCastTo32();

		// Calculate the number of seconds the old timeDelinquent had remaining
		// outside the grace period, or zero if it was already in the grace period.
		uint256 secondsRemainingWithPenalty = previousTimeDelinquent.satSub(delinquencyGracePeriod);

		// Only apply penalties for the remaining time outside of the grace period.
		return MathUtils.min(secondsRemainingWithPenalty, timeDelta);
	}
}

// /**
//  * @dev Calculate the new total time in delinquency and the time
//  * outside of the grace period since the last update.
//  * @param state Encoded state parameters
//  * @param timeElapsed Time since last update
//  * @param delinquencyGracePeriod Threshold before delinquency incurs penalties
//  * @return timeWithPenalty Seconds since last update where penalties applied
//  */
// function _calculateDelinquencyTime(
// 	VaultState memory state,
// 	uint256 timeElapsed,
// 	uint256 delinquencyGracePeriod
// ) pure returns (uint256 timeWithPenalty) {
// 	bool isDelinquent = state.isDelinquent;
// 	uint256 timeDelinquent = state.timeDelinquent;

// 	uint256 previousTimeDelinquent = state.timeDelinquent;

// 	if (isDelinquent) {
// 		state.timeDelinquent = (timeDelinquent + timeElapsed).safeCastTo32();

// 		// Get the number of seconds the old timeDelinquent was from exceeding
// 		// the grace period, or zero if it was already past the grace period.
// 		uint256 secondsWithoutPenalty = delinquencyGracePeriod.satSub(
// 			previousTimeDelinquent
// 		);

// 		/*  max(elapsed - max(delinquencyGracePeriod - timeDelinquent, 0), 0) */
// 		// Subtract the remainder of the grace period from the time elapsed
// 		timeWithPenalty = uint256(timeElapsed).satSub(secondsWithoutPenalty);
// 	} else {
// 		// Get the number of seconds the old timeDelinquent had remaining
// 		// in the grace period, or zero if it was already in the grace period.
// 		uint256 secondsWithPenalty = timeDelinquent.satSub(delinquencyGracePeriod);
// 		// The time with penalty in the last interval is the min of:
// 		// timeDelinquent - delinquencyGracePeriod, timeElapsed, 0
// 		timeWithPenalty = Math.min(secondsWithPenalty, timeElapsed);
// 		// Reduce `timeDelinquent` by time elapsed until it hits zero
// 		state.timeDelinquent = timeDelinquent
// 			.satSub(timeElapsed)
// 			.safeCastTo32();

// 		/* min(timeElapsed, max(timeDelinquent - delinquencyGracePeriod, 0)) */
// 	}
// }
