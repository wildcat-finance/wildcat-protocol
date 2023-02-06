// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import '../types/CoderConstants.sol';

uint256 constant BipsOne = 1e4;
uint256 constant OneEth = 1e18;
uint256 constant RayOne = 1e26;
uint256 constant RayBipsNumerator = 1e22;
uint256 constant SecondsIn365Days = 31536000;

library Math {
	function avg(uint256 a, uint256 b) internal pure returns (uint256 c) {
		c = (a & b) + (a ^ b) / 2;
	}

	function min(uint256 a, uint256 b) internal pure returns (uint256 c) {
		c = ternary(a < b, a, b);
	}

	function max(uint256 a, uint256 b) internal pure returns (uint256 c) {
		c = ternary(a < b, b, a);
	}

	function subMinZero(uint256 a, uint256 b) internal pure returns (uint256 c) {
		unchecked {
			c = ternary(a > b, a - b, 0);
		}
	}

	function rayMul(uint256 x, uint256 y) internal pure returns (uint256 z) {
		z = (x * y) / RayOne;
	}

	function rayDiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
		z = (x * RayOne) / y;
	}

	function bipsMul(uint256 x, uint256 y) internal pure returns (uint256 z) {
		z = (x * y) / BipsOne;
	}

	function ternary(
		bool condition,
		uint256 valueIfTrue,
		uint256 valueIfFalse
	) internal pure returns (uint256 c) {
		assembly {
			c := add(valueIfFalse, mul(condition, sub(valueIfTrue, valueIfFalse)))
		}
	}

	function annualBipsToRayPerSecond(uint256 annualBips)
		internal
		pure
		returns (uint256 rayPerSecond)
	{
		assembly {
			// Convert annual bips to fraction of 1e26 - (bips * 1e22) / 31536000
			// Multiply by 1e22 = multiply by 1e26 and divide by 10000
			rayPerSecond := div(mul(annualBips, RayBipsNumerator), SecondsIn365Days)
		}
	}
}
