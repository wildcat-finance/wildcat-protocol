// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import '../Errors.sol';

uint256 constant BIP = 1e4;
uint256 constant HALF_BIP = 0.5e4;

// HALF_WAD and HALF_RAY expressed with extended notation as constant with operations are not supported in Yul assembly
uint256 constant WAD = 1e18;
uint256 constant HALF_WAD = 0.5e18;

uint256 constant RAY = 1e27;
uint256 constant HALF_RAY = 0.5e27;

uint256 constant WAD_RAY_RATIO = 1e9;

uint256 constant BIP_WAD_RATIO = 1e14;

uint256 constant BIP_RAY_RATIO = 1e23;

/**
 * @title WadRayMath library
 * @author Aave
 * @notice Provides functions to perform calculations with Wad and Ray units
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits of precision) and rays (decimal numbers
 * with 27 digits of precision)
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 */
library WadRayMath {

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
	 * @dev Multiplies two wad, rounding half up to the nearest wad
	 * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
	 * @param a Wad
	 * @param b Wad
	 * @return c = a*b, in wad
	 */
	function wadMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
		// to avoid overflow, a <= (type(uint256).max - HALF_WAD) / b
		assembly {
			if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_WAD), b))))) {
				mstore(0, Panic_ErrorSelector)
				mstore(Panic_ErrorCodePointer, Panic_Arithmetic)
				revert(Error_SelectorPointer, Panic_ErrorLength)
			}

			c := div(add(mul(a, b), HALF_WAD), WAD)
		}
	}

	/**
	 * @dev Divides two wad, rounding half up to the nearest wad
	 * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
	 * @param a Wad
	 * @param b Wad
	 * @return c = a/b, in wad
	 */
	function wadDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
		// to avoid overflow, a <= (type(uint256).max - halfB) / WAD
		assembly {
			if or(
				iszero(b),
				iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), WAD))))
			) {
				mstore(0, Panic_ErrorSelector)
				mstore(Panic_ErrorCodePointer, Panic_Arithmetic)
				revert(Error_SelectorPointer, Panic_ErrorLength)
			}

			c := div(add(mul(a, WAD), div(b, 2)), b)
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
			if or(
				iszero(b),
				iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), RAY))))
			) {
				mstore(0, Panic_ErrorSelector)
				mstore(Panic_ErrorCodePointer, Panic_Arithmetic)
				revert(Error_SelectorPointer, Panic_ErrorLength)
			}

			c := div(add(mul(a, RAY), div(b, 2)), b)
		}
	}

	/**
	 * @dev Casts ray down to wad
	 * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
	 * @param a Ray
	 * @return b = a converted to wad, rounded half up to the nearest wad
	 */
	function rayToWad(uint256 a) internal pure returns (uint256 b) {
		assembly {
			b := div(a, WAD_RAY_RATIO)
			let remainder := mod(a, WAD_RAY_RATIO)
			if iszero(lt(remainder, div(WAD_RAY_RATIO, 2))) {
				b := add(b, 1)
			}
		}
	}

	/**
	 * @dev Converts wad up to ray
	 * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
	 * @param a Wad
	 * @return b = a converted in ray
	 */
	function wadToRay(uint256 a) internal pure returns (uint256 b) {
		// to avoid overflow, b/WAD_RAY_RATIO == a
		assembly {
			b := mul(a, WAD_RAY_RATIO)

			if iszero(eq(div(b, WAD_RAY_RATIO), a)) {
				mstore(0, Panic_ErrorSelector)
				mstore(Panic_ErrorCodePointer, Panic_Arithmetic)
				revert(Error_SelectorPointer, Panic_ErrorLength)
			}
		}
	}

	/**
	 * @dev Converts bip up to wad
	 * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
	 * @param a bip
	 * @return b = a converted in wad
	 */
	function bipToWad(uint256 a) internal pure returns (uint256 b) {
		// to avoid overflow, b/BIP_WAD_RATIO == a
		assembly {
			b := mul(a, BIP_WAD_RATIO)

			if iszero(eq(div(b, BIP_WAD_RATIO), a)) {
				mstore(0, Panic_ErrorSelector)
				mstore(Panic_ErrorCodePointer, Panic_Arithmetic)
				revert(Error_SelectorPointer, Panic_ErrorLength)
			}
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
}
