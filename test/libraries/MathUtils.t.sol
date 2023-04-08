import "reference/libraries/math/MathUtils.sol";
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
}