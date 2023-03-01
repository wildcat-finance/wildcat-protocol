// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import '../types/ScaleParametersCoder.sol';
import '../types/VaultSupplyCoder.sol';
import './Math.sol';

using Math for uint256;

function _calculateInterestAccrued(uint256 annualInterestBips, uint256 secondsElapsed) pure returns (uint256) {
  // Convert annual interest rate in bips to ray per second
  uint256 interestPerSecond = annualInterestBips.annualBipsToRayPerSecond();

  // Calculate interest accrued over interval
  return secondsElapsed * interestPerSecond;
}

// using ScaleParametersCoder for ScaleParameters;
// using VaultSupplyCoder for VaultSupply;
/**
 * @dev Calculates interest and protocol fees accrued since last state update. and applies it to
 * cached state returns protocol fees accrued.
 *
 * @param scaleParameters Vault scale parameters
 * @param vaultSupply Vault supply
 * @param interestFeeBips Protocol fee on interest
 * @return newScaleParameters Scale parameters with updated scaleFactor and timestamp after accruing fees
 * @return feesAccrued Protocol fees owed on interest
 * @return didUpdate Whether interest has accrued since last update
 */
function _calculateInterestAndFees(
	ScaleParameters scaleParameters,
	VaultSupply vaultSupply,
	uint256 interestFeeBips,
  uint256 penaltyFeeBips,
	uint256 gracePeriod
)
	view
	returns (
		ScaleParameters, /* newScaleParameters */
		uint256, /* feesAccrued */
		bool /* didUpdate */
	)
{
	(
		uint256 annualInterestBips,
		uint256 scaleFactor,
		uint256 lastInterestAccruedTimestamp
	) = scaleParameters.getNewScaleInputs();

	uint256 feesAccrued;
	uint256 timeElapsed = block.timestamp - lastInterestAccruedTimestamp;

	bool didUpdate = timeElapsed > 0;

	// If no time has passed since last update, calculate interest
	if (didUpdate) {
		uint256 scaleFactorDelta;
		unchecked {
      // Calculate interest accrued since last update
      uint256 interestAccrued = _calculateInterestAccrued(annualInterestBips, timeElapsed);
      {
        uint256 timeWithPenalty;
        (scaleParameters, timeWithPenalty) = _calculateDelinquencyTimes(scaleParameters, timeElapsed, gracePeriod);
        if (timeWithPenalty > 0) {
          interestAccrued += _calculateInterestAccrued(penaltyFeeBips, timeWithPenalty);
        }
      }
			// Compound growth of scaleFactor
			scaleFactorDelta = scaleFactor.rayMul(interestAccrued);
		}
		if (interestFeeBips > 0) {
			// Calculate fees accrued to protocol
			feesAccrued = vaultSupply.getScaledTotalSupply().rayMul(
				scaleFactorDelta.bipsMul(interestFeeBips)
			);

			// Unchecked because interestFeeBips can not exceed BipsOne
			unchecked {
				// Subtract fee
				scaleFactorDelta = scaleFactorDelta.bipsMul(BipsOne - interestFeeBips);
			}
		}
		// Update scaleFactor and timestamp
		scaleParameters = scaleParameters.setNewScaleOutputs(
			scaleFactor + scaleFactorDelta,
			block.timestamp
		);
	}

	return (scaleParameters, feesAccrued, didUpdate);
}

/**
 * @dev Calculate the new total time in delinquency and the time
 * outside of the grace period since the last update.
 * @param state Encoded state parameters
 * @param timeElapsed Time since last update
 * @param gracePeriod Threshold before delinquency incurs penalties
 * @return newState State with updated `timeDelinquent`
 * @return timeWithPenalty Seconds since last update where penalties applied
 */
function _calculateDelinquencyTimes(
	ScaleParameters state,
	uint256 timeElapsed,
	uint256 gracePeriod
) pure returns (ScaleParameters newState, uint256 timeWithPenalty) {
	(bool isDelinquent, uint256 timeDelinquent) = state.getDelinquency();
	if (isDelinquent) {
		newState = state.setTimeDelinquent(timeDelinquent + timeElapsed);
		// Get the number of seconds the old timeDelinquent was from exceeding
		// the grace period, or zero if it was already past the grace period.
		uint256 secondsWithoutPenalty = gracePeriod.subMinZero(timeDelinquent);
		/*  max(elapsed - max(gracePeriod - timeDelinquent, 0), 0) */
		// Subtract the remainder of the grace period from the time elapsed
		timeWithPenalty = timeElapsed.subMinZero(secondsWithoutPenalty);
	} else {
		// Get the number of seconds the old timeDelinquent had remaining
		// in the grace period, or zero if it was already in the grace period.
		uint256 secondsWithPenalty = timeDelinquent.subMinZero(gracePeriod);
		// The time with penalty in the last duration is the min of:
		// timeDelinquent - gracePeriod, timeElapsed, 0
		timeWithPenalty = Math.min(secondsWithPenalty, timeElapsed);
		// Reduce `timeDelinquent` by time elapsed until it hits zero
		newState = state.setTimeDelinquent(timeDelinquent.subMinZero(timeElapsed));
	}
}

// Suppose old time was 105, grace period is 100
// it's been 30 seconds
// if (oldTime > gracePeriod):
//   penaltyTime = newTime > gracePeriod ? timeElapsed : oldTime - gracePeriod
