// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../BaseMarketTest.sol';

contract WildcatMarketBaseTest is BaseMarketTest {
  // ===================================================================== //
  //                          coverageLiquidity()                          //
  // ===================================================================== //

  function test_coverageLiquidity() external {
    market.coverageLiquidity();
  }

  // ===================================================================== //
  //                             scaleFactor()                             //
  // ===================================================================== //

  function test_scaleFactor() external {
    assertEq(market.scaleFactor(), 1e27, 'scaleFactor should be 1 ray');
    fastForward(365 days);
    assertEq(market.scaleFactor(), 1.1e27, 'scaleFactor should grow by 10% from APR');
    // updateState(pendingState());
    // Deposit one token
    _deposit(alice, 1e18);
    // Borrow 80% of market assets
    _borrow(8e17);
    assertEq(market.currentState().isDelinquent, false);
    // Withdraw 100% of deposits
    _requestWithdrawal(alice, 1e18);
    assertEq(market.scaleFactor(), 1.1e27);
    // Fast forward to delinquency grace period
    fastForward(2000);
    MarketState memory state = previousState;
    uint256 scaleFactorAtGracePeriodExpiry = uint(1.1e27) +
      MathUtils.rayMul(
        1.1e27,
        FeeMath.calculateLinearInterestFromBips(parameters.annualInterestBips, 2_000)
      );
    assertEq(market.scaleFactor(), scaleFactorAtGracePeriodExpiry);
    // uint256 dayOneInterest = FeeMath.calculateLinearInterestFromBips(
    // 	1000,
    // 	86_400
    // );
    // uint256 scaleFactorDayOne = 1.1e27 + MathUtils.rayMul(1.1e27, dayOneInterest);
    // uint256 scaleFactor = scaleFactorDayOne +
    // 	MathUtils.rayMul(scaleFactorDayOne, FeeMath.calculateLinearInterestFromBips(2000, 364 days));

    // assertEq(
    // 	market.scaleFactor(),
    // 	scaleFactor,
    // 	'scaleFactor should grow by 20% with delinquency fees'
    // );
  }

  // ===================================================================== //
  //                             totalAssets()                             //
  // ===================================================================== //

  function test_totalAssets() external {
    market.totalAssets();
  }

  // ===================================================================== //
  //                          borrowableAssets()                           //
  // ===================================================================== //

  function test_borrowableAssets() external {
    assertEq(market.borrowableAssets(), 0, 'borrowable should be 0');

    _deposit(alice, 50_000e18);
    assertEq(market.borrowableAssets(), 40_000e18, 'borrowable should be 40k');
    // market.borrowableAssets();
  }

  // ===================================================================== //
  //                         accruedProtocolFees()                         //
  // ===================================================================== //

  function test_accruedProtocolFees() external {
    market.accruedProtocolFees();
  }

  // ===================================================================== //
  //                            previousState()                            //
  // ===================================================================== //

  function test_previousState() external {
    market.previousState();
  }

  // ===================================================================== //
  //                            currentState()                             //
  // ===================================================================== //

  function test_currentState() external {
    market.currentState();
  }

  // ===================================================================== //
  //                          scaledTotalSupply()                          //
  // ===================================================================== //

  function test_scaledTotalSupply() external {
    market.scaledTotalSupply();
  }

  // ===================================================================== //
  //                       scaledBalanceOf(address)                        //
  // ===================================================================== //

  function test_scaledBalanceOf(address account) external {
    market.scaledBalanceOf(account);
  }

  function test_scaledBalanceOf() external {
    address account;
    market.scaledBalanceOf(account);
  }

  // ===================================================================== //
  //                        effectiveBorrowerAPR()                         //
  // ===================================================================== //

  function test_effectiveBorrowerAPR() external {
    assertEq(market.effectiveBorrowerAPR(), 1.1e26);
    _deposit(alice, 1e18);
    _borrow(8e17);
    _requestWithdrawal(alice, 1e18);
    assertEq(market.effectiveBorrowerAPR(), 1.1e26);
    fastForward(2_001);
    assertEq(market.effectiveBorrowerAPR(), 2.1e26);
  }

  // ===================================================================== //
  //                         effectiveLenderAPR()                          //
  // ===================================================================== //

  function test_effectiveLenderAPR() external {
    assertEq(market.effectiveLenderAPR(), 1e26);
    _deposit(alice, 1e18);
    _borrow(8e17);
    _requestWithdrawal(alice, 1e18);
    assertEq(market.effectiveLenderAPR(), 1e26);
    fastForward(2_001);
    assertEq(market.effectiveLenderAPR(), 2e26);
  }

  // ===================================================================== //
  //                      withdrawableProtocolFees()                       //
  // ===================================================================== //

  function test_withdrawableProtocolFees() external {
    assertEq(market.withdrawableProtocolFees(), 0);
    _deposit(alice, 1e18);
    fastForward(365 days);
    assertEq(market.withdrawableProtocolFees(), 1e16);
  }

  function test_withdrawableProtocolFees_LessNormalizedUnclaimedWithdrawals() external {
    assertEq(market.withdrawableProtocolFees(), 0);
    _deposit(alice, 1e18);
    _borrow(8e17);
    fastForward(365 days);
    _requestWithdrawal(alice, 1e18);
    assertEq(market.withdrawableProtocolFees(), 1e16);
    asset.mint(address(market), 8e17 + 1);
    assertEq(market.withdrawableProtocolFees(), 1e16);
  }
}
