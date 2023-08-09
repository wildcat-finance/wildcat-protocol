// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "reference/libraries/MathUtils.sol";
import "forge-std/Test.sol";

contract MathUtilsTest is Test {
  // function testFuzzCalculateLinearInterest(uint256 bips, uint256 delta) external {
  //   bips = bound(bips, 0, 10000);
  //   delta = bound(delta, 0, 365 days);
  // }
  function testCalculateLinearInterestFromBips() external {
    assertEq(
      MathUtils.calculateLinearInterestFromBips(1000, 365 days),
      1e26
    );
  }

  function testSatSub(uint256 a, uint256 b) external {
    if (b > a) {
      assertEq(MathUtils.satSub(a, b), 0);
    } else {
      assertEq(MathUtils.satSub(a, b), a - b);
    }
  }
}