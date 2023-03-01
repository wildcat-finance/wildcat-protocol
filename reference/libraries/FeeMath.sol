// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './Math.sol';
import './SafeCastLib.sol';
import './VaultState.sol';

using Math for uint256;
using SafeCastLib for uint256;

function _calculateInterestAccrued(uint256 annualInterestBips, uint256 secondsElapsed) pure returns (uint256) {
  // Convert annual interest rate in bips to ray per second
  uint256 interestPerSecond = uint256(annualInterestBips).annualBipsToRayPerSecond();

  // Calculate interest accrued over interval
  return secondsElapsed * interestPerSecond;
}

/**
 * @dev Calculates interest and protocol fees accrued since last state update. and applies it to
 * cached state returns protocol fees accrued.
 *
 * @param state Vault scale parameters
 * @param interestFeeBips Protocol fee on interest
 * @return feesAccrued Protocol fees owed on interest
 * @return didUpdate Whether interest has accrued since last update
 */
function _calculateInterestAndFees(
	VaultState memory state,
	uint256 interestFeeBips,
  uint256 penaltyFeeBips,
	uint256 gracePeriod
)
	view
	returns (
		uint256 feesAccrued,
		bool didUpdate
	)
{
	uint256 scaleFactor = state.scaleFactor;
	uint256 lastInterestAccruedTimestamp = state.lastInterestAccruedTimestamp;

	uint256 timeElapsed = block.timestamp - lastInterestAccruedTimestamp;
	didUpdate = timeElapsed > 0;

	// If no time has passed since last update, calculate interest
	if (didUpdate) {
    uint256 interestAccrued = _calculateInterestAccrued(state.annualInterestBips, timeElapsed);

    uint256 timeWithPenalty = _calculateDelinquencyTime(state, timeElapsed, gracePeriod);

    if (timeWithPenalty > 0) {
      interestAccrued += _calculateInterestAccrued(penaltyFeeBips, timeWithPenalty);
    }

    // Compound growth of scaleFactor
    uint256 scaleFactorDelta = scaleFactor.rayMul(interestAccrued);
    
		if (interestFeeBips > 0) {
			// Calculate fees accrued to protocol
			feesAccrued = uint256(state.scaledTotalSupply).rayMul(
				scaleFactorDelta.bipsMul(interestFeeBips)
			);

			// Unchecked because interestFeeBips can not exceed BipsOne
			unchecked {
				// Subtract fee
				scaleFactorDelta = scaleFactorDelta.bipsMul(BipsOne - interestFeeBips);
			}
		}
		// Update scaleFactor and timestamp
		state.scaleFactor = (scaleFactor + scaleFactorDelta).safeCastTo112();
		state.lastInterestAccruedTimestamp = uint32(block.timestamp);
	}

	return (feesAccrued, didUpdate);
}

/**
 * @dev Calculate the new total time in delinquency and the time
 * outside of the grace period since the last update.
 * @param state Encoded state parameters
 * @param timeElapsed Time since last update
 * @param gracePeriod Threshold before delinquency incurs penalties
 * @return timeWithPenalty Seconds since last update where penalties applied
 */
function _calculateDelinquencyTime(
	VaultState memory state,
	uint256 timeElapsed,
	uint256 gracePeriod
) pure returns (uint256 timeWithPenalty) {
  bool isDelinquent = state.isDelinquent;
  uint256 timeDelinquent = state.timeDelinquent;
	if (isDelinquent) {
    state.timeDelinquent = (uint256(state.timeDelinquent) + timeElapsed).safeCastTo32();
		// Get the number of seconds the old timeDelinquent was from exceeding
		// the grace period, or zero if it was already past the grace period.
		uint256 secondsWithoutPenalty = gracePeriod.subMinZero(timeDelinquent);
		/*  max(elapsed - max(gracePeriod - timeDelinquent, 0), 0) */
		// Subtract the remainder of the grace period from the time elapsed
		timeWithPenalty = uint256(timeElapsed).subMinZero(secondsWithoutPenalty);
	} else {
		// Get the number of seconds the old timeDelinquent had remaining
		// in the grace period, or zero if it was already in the grace period.
		uint256 secondsWithPenalty = timeDelinquent.subMinZero(gracePeriod);
		// The time with penalty in the last interval is the min of:
		// timeDelinquent - gracePeriod, timeElapsed, 0
		timeWithPenalty = Math.min(secondsWithPenalty, timeElapsed);
		// Reduce `timeDelinquent` by time elapsed until it hits zero
    state.timeDelinquent = timeDelinquent.subMinZero(timeElapsed).safeCastTo32();
	}
}