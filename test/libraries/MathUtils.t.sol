// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'reference/libraries/MathUtils.sol';
import 'forge-std/Test.sol';

contract MathUtilsTest is Test {
	// function testFuzzCalculateLinearInterest(uint256 bips, uint256 delta) external {
	//   bips = bound(bips, 0, 10000);
	//   delta = bound(delta, 0, 365 days);
	// }
	function test_calculateLinearInterestFromBips() external {
		assertEq(MathUtils.calculateLinearInterestFromBips(1000, 365 days), 1e26);
	}

	function test_satSub(uint256 a, uint256 b) external {
		if (b > a) {
			assertEq(MathUtils.satSub(a, b), 0);
		} else {
			assertEq(MathUtils.satSub(a, b), a - b);
		}
	}

	function _mulDiv(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
		return MathUtils.mulDiv(a, b, c);
	}

	function test_mulDiv(uint256 a, uint256 b, uint256 c) external {
		if (c == 0 || (b != 0 && a > (type(uint256).max / b))) {
			vm.expectRevert(MathUtils.MulDivFailed.selector);
			this._mulDiv(a, b, c);
		} else {
			assertEq(this._mulDiv(a, b, c), (a * b) / c);
		}
	}
}
