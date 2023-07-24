// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import './Errors.sol';

uint256 constant BIP = 1e4;
uint256 constant HALF_BIP = 0.5e4;

uint256 constant RAY = 1e27;
uint256 constant HALF_RAY = 0.5e27;

uint256 constant BIP_RAY_RATIO = 1e23;

uint256 constant SECONDS_IN_365_DAYS = 365 days;

/**
 * @title MathUtils library
 * @author Aave
 * @notice Provides functions to perform linear and compounded interest calculations
 */
library MathUtils {
	error InvalidNullValue();

	using MathUtils for uint256;

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

	/**
	 * @dev Multiplies two bip, rounding half up to the nearest bip
	 * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
	 * @param a Bip
	 * @param b Bip
	 * @return c = a*b, in bip
	 */
	function bipMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
		// to avoid overflow, a <= (type(uint256).max - HALF_WAD) / b
		assembly {
			if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_BIP), b))))) {
				// Store the Panic error signature.
				mstore(0, Panic_ErrorSelector)
				// Store the arithmetic (0x11) panic code.
				mstore(Panic_ErrorCodePointer, Panic_Arithmetic)
				// revert(abi.encodeWithSignature("Panic(uint256)", 0x11))
				revert(Error_SelectorPointer, Panic_ErrorLength)
			}

			c := div(add(mul(a, b), HALF_BIP), BIP)
		}
	}

	/**
	 * @notice Divides two bip, rounding half up to the nearest bip
	 * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
	 * @param a Bip
	 * @param b Bip
	 * @return c = a bipdiv b
	 */
	function bipDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
		// to avoid overflow, a <= (type(uint256).max - halfB) / BIP
		assembly {
			if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), BIP))))) {
				mstore(0, Panic_ErrorSelector)
				mstore(Panic_ErrorCodePointer, Panic_Arithmetic)
				revert(Error_SelectorPointer, Panic_ErrorLength)
			}

			c := div(add(mul(a, BIP), div(b, 2)), b)
		}
	}

	/**
	 * @dev Converts bip up to ray
	 * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
	 * @param a bip
	 * @return b = a converted in ray
	 */
	function bipToRay(uint256 a) internal pure returns (uint256 b) {
		// to avoid overflow, b/BIP_RAY_RATIO == a
		assembly {
			b := mul(a, BIP_RAY_RATIO)

			if iszero(eq(div(b, BIP_RAY_RATIO), a)) {
				mstore(0, Panic_ErrorSelector)
				mstore(Panic_ErrorCodePointer, Panic_Arithmetic)
				revert(Error_SelectorPointer, Panic_ErrorLength)
			}
		}
	}

	/**
	 * @notice Multiplies two ray, rounding half up to the nearest ray
	 * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
	 * @param a Ray
	 * @param b Ray
	 * @return c = a raymul b
	 */
	function rayMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
		// to avoid overflow, a <= (type(uint256).max - HALF_RAY) / b
		assembly {
			if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_RAY), b))))) {
				mstore(0, Panic_ErrorSelector)
				mstore(Panic_ErrorCodePointer, Panic_Arithmetic)
				revert(Error_SelectorPointer, Panic_ErrorLength)
			}

			c := div(add(mul(a, b), HALF_RAY), RAY)
		}
	}

	/**
	 * @notice Divides two ray, rounding half up to the nearest ray
	 * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
	 * @param a Ray
	 * @param b Ray
	 * @return c = a raydiv b
	 */
	function rayDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
		// to avoid overflow, a <= (type(uint256).max - halfB) / RAY
		assembly {
			if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), RAY))))) {
				mstore(0, Panic_ErrorSelector)
				mstore(Panic_ErrorCodePointer, Panic_Arithmetic)
				revert(Error_SelectorPointer, Panic_ErrorLength)
			}

			c := div(add(mul(a, RAY), div(b, 2)), b)
		}
	}
}
