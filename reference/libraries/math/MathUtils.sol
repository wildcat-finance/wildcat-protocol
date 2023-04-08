// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { WadRayMath, RAY } from './WadRayMath.sol';

/**
 * @title MathUtils library
 * @author Aave
 * @notice Provides functions to perform linear and compounded interest calculations
 */
library MathUtils {
	using WadRayMath for uint256;

	error InvalidNullValue();

	uint256 internal constant SECONDS_IN_365_DAYS = 365 days;

	/**
	 * @dev Calculate time elapsed since a given timestamp.
	 *
	 * NOTE: `lastUpdateTimestamp` Must be less than the current timestamp, as
	 *        the subtraction is not checked for underflow.
	 *
	 * @return `timeElapsed` Seconds elapsed since `lastUpdateTimestamp`
	 */
	function timeElapsedSince(
		uint256 lastUpdateTimestamp
	) internal view returns (uint256) {
		unchecked {
			return block.timestamp - lastUpdateTimestamp;
		}
	}

	/**
	 * @dev Function to calculate the interest accumulated using a linear interest rate formula
	 *
	 * @param rate The interest rate, in ray
	 * @param timeDelta The time elapsed since the last interest accrual
	 * @return The interest rate linearly accumulated during the timeDelta, in ray
	 */
	function calculateLinearInterest(
		uint256 rate,
		uint256 timeDelta
	) internal pure returns (uint256) {
		uint256 result = rate * timeDelta;
		unchecked {
			result = result / SECONDS_IN_365_DAYS;
		}

		return result;
	}

	/**
	 * @dev Function to calculate the interest accumulated using a linear interest rate formula
	 *
	 * @param rate The interest rate, in bips
	 * @param timeDelta The time elapsed since the last interest accrual
	 * @return The interest rate linearly accumulated during the timeDelta, in ray
	 */
	function calculateLinearInterestFromBips(
		uint256 rate,
		uint256 timeDelta
	) internal pure returns (uint256) {
		rate = rate.bipToRay();

		uint256 result = rate * timeDelta;
		unchecked {
			result = result / SECONDS_IN_365_DAYS;
		}

		return result;
	}

	/**
	 * @dev Function to calculate the interest using a compounded interest rate formula
	 * To avoid expensive exponentiation, the calculation is performed using a binomial approximation:
	 *
	 *  (1+x)^n = 1+n*x+[n/2*(n-1)]*x^2+[n/6*(n-1)*(n-2)*x^3...
	 *
	 * The approximation slightly underpays liquidity providers and undercharges borrowers, with the advantage of great
	 * gas cost reductions. The whitepaper contains reference to the approximation and a table showing the margin of
	 * error per different time periods
	 *
	 * @param rate The interest rate, in ray
	 * @param lastUpdateTimestamp The timestamp of the last update of the interest
	 * @param currentTimestamp The timestamp to end interest accumulation
	 * @return The interest rate compounded during the timeDelta, in ray
	 */
	function calculateCompoundedInterest(
		uint256 rate,
		uint256 lastUpdateTimestamp,
		uint256 currentTimestamp
	) internal pure returns (uint256) {
		//solium-disable-next-line
		uint256 exp = currentTimestamp - lastUpdateTimestamp;

		if (exp == 0) {
			return RAY;
		}

		uint256 expMinusOne;
		uint256 expMinusTwo;
		uint256 basePowerTwo;
		uint256 basePowerThree;
		unchecked {
			expMinusOne = exp - 1;

			expMinusTwo = exp > 2 ? exp - 2 : 0;

			basePowerTwo =
				rate.rayMul(rate) /
				(SECONDS_IN_365_DAYS * SECONDS_IN_365_DAYS);
			basePowerThree = basePowerTwo.rayMul(rate) / SECONDS_IN_365_DAYS;
		}

		uint256 secondTerm = exp * expMinusOne * basePowerTwo;
		unchecked {
			secondTerm /= 2;
		}
		uint256 thirdTerm = exp * expMinusOne * expMinusTwo * basePowerThree;
		unchecked {
			thirdTerm /= 6;
		}

		return
			RAY +
			(rate * exp) /
			SECONDS_IN_365_DAYS +
			secondTerm +
			thirdTerm;
	}

	/**
	 * @dev Calculates the compounded interest between the timestamp of the last update and the current block timestamp
	 * @param rate The interest rate (in ray)
	 * @param lastUpdateTimestamp The timestamp from which the interest accumulation needs to be calculated
	 * @return The interest rate compounded between lastUpdateTimestamp and current block timestamp, in ray
	 */
	function calculateCompoundedInterest(
		uint256 rate,
		uint40 lastUpdateTimestamp
	) internal view returns (uint256) {
		return
			calculateCompoundedInterest(rate, lastUpdateTimestamp, block.timestamp);
	}

	/**
	 * @dev Return the smaller of `a` and `b`
	 */
	function min(uint256 a, uint256 b) internal pure returns (uint256 c) {
		c = ternary(a < b, a, b);
	}

	/**
	 * @dev Return the larger of `a` and `b`.
	 */
	function max(uint256 a, uint256 b) internal pure returns (uint256 c) {
		c = ternary(a < b, b, a);
	}

	/**
	 * @dev Saturation subtraction. Subtract `b` from `a` and return the result
   * if it is positive or zero if it underflows.
	 */
	function satSub(uint256 a, uint256 b) internal pure returns (uint256 c) {
		assembly {
			// (a > b) * (a - b)
			// If a-b underflows, the product will be zero
			c := mul(gt(a, b), sub(a, b))
		}
	}

	/**
	 * @dev Return `valueIfTrue` if `condition` is true and `valueIfFalse` if it is false.
	 *      Equivalent to `condition ? valueIfTrue : valueIfFalse`
	 */
	function ternary(
		bool condition,
		uint256 valueIfTrue,
		uint256 valueIfFalse
	) internal pure returns (uint256 c) {
		assembly {
			c := add(valueIfFalse, mul(condition, sub(valueIfTrue, valueIfFalse)))
		}
	}

	function lowestBitSet(uint256 self) internal pure returns (uint256 _z) {
		if (self == 0) {
			revert InvalidNullValue();
		}
		uint256 _magic = 0x00818283848586878898a8b8c8d8e8f929395969799a9b9d9e9faaeb6bedeeff;
		uint256 val;
		assembly {
			val := shr(248, mul(and(self, sub(0, self)), _magic))
		}
		uint256 _y = val >> 5;

		_z = (
			_y < 4
				? _y < 2
					? ternary(
						_y == 0,
						0x753a6d1b65325d0c552a4d1345224105391a310b29122104190a110309020100,
						0xc976c13bb96e881cb166a933a55e490d9d56952b8d4e801485467d2362422606
					)
					: ternary(
						_y == 2,
						0xe39ed557db96902cd38ed14fad815115c786af479b7e83247363534337271707,
						0xf7cae577eec2a03cf3bad76fb589591debb2dd67e0aa9834bea6925f6a4a2e0e
					)
				: _y < 6
				? ternary(
					_y == 4,
					0xc8c0b887b0a8a4489c948c7f847c6125746c645c544c444038302820181008ff,
					0xf6e4ed9ff2d6b458eadcdf97bd91692de2d4da8fd2d0ac50c6ae9a8272523616
				)
				: ternary(
					_y == 6,
					0xf5ecf1b3e9debc68e1d9cfabc5997135bfb7a7a3938b7b606b5b4b3f2f1f0ffe,
					0xf8f9cbfae6cc78fbefe7cdc3a1793dfcf4f0e8bbd8cec470b6a28a7a5a3e1efd
				)
		);
		assembly {
			// _z = (_z >> (val & 0x1f) << 3) & 0xff
			_z := and(shr(shl(3, and(val, 0x1f)), _z), 0xff)
		}
		return _z;
	}
}
