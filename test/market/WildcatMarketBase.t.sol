// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../BaseVaultTest.sol';

contract WildcatMarketBaseTest is BaseVaultTest {
  // ===================================================================== //
  //                          coverageLiquidity()                          //
  // ===================================================================== //

  function test_coverageLiquidity() external {
    vault.coverageLiquidity();
  }

  // ===================================================================== //
  //                             scaleFactor()                             //
  // ===================================================================== //

  function test_scaleFactor() external {
    assertEq(vault.scaleFactor(), 1e27, 'scaleFactor should be 1 ray');
    fastForward(365 days);
    assertEq(vault.scaleFactor(), 1.1e27, 'scaleFactor should grow by 10% from APR');
    // updateState(pendingState());
    // Deposit one token
    _deposit(alice, 1e18);
    // Borrow 80% of vault assets
    _borrow(8e17);
    assertEq(vault.currentState().isDelinquent, false);
    // Withdraw 100% of deposits
    _requestWithdrawal(alice, 1e18);
    assertEq(vault.scaleFactor(), 1.1e27);
    // Fast forward to delinquency grace period
    fastForward(2000);
    VaultState memory state = previousState;
    uint256 scaleFactorAtGracePeriodExpiry = uint(1.1e27) +
      MathUtils.rayMul(
        1.1e27,
        FeeMath.calculateLinearInterestFromBips(parameters.annualInterestBips, 2_000)
      );
    assertEq(vault.scaleFactor(), scaleFactorAtGracePeriodExpiry);
    // uint256 dayOneInterest = FeeMath.calculateLinearInterestFromBips(
    // 	1000,
    // 	86_400
    // );
    // uint256 scaleFactorDayOne = 1.1e27 + MathUtils.rayMul(1.1e27, dayOneInterest);
    // uint256 scaleFactor = scaleFactorDayOne +
    // 	MathUtils.rayMul(scaleFactorDayOne, FeeMath.calculateLinearInterestFromBips(2000, 364 days));

    // assertEq(
    // 	vault.scaleFactor(),
    // 	scaleFactor,
    // 	'scaleFactor should grow by 20% with delinquency fees'
    // );
  }

  // ===================================================================== //
  //                             totalAssets()                             //
  // ===================================================================== //

  function test_totalAssets() external {
    vault.totalAssets();
  }

  // ===================================================================== //
  //                          borrowableAssets()                           //
  // ===================================================================== //

  function test_borrowableAssets() external {
    assertEq(vault.borrowableAssets(), 0, 'borrowable should be 0');

    _deposit(alice, 50_000e18);
    assertEq(vault.borrowableAssets(), 40_000e18, 'borrowable should be 40k');
    // vault.borrowableAssets();
  }

  // ===================================================================== //
  //                         accruedProtocolFees()                         //
  // ===================================================================== //

  function test_accruedProtocolFees() external {
    vault.accruedProtocolFees();
  }

  // ===================================================================== //
  //                            previousState()                            //
  // ===================================================================== //

  function test_previousState() external {
    vault.previousState();
  }

  // ===================================================================== //
  //                            currentState()                             //
  // ===================================================================== //

  function test_currentState() external {
    vault.currentState();
  }

  // ===================================================================== //
  //                          scaledTotalSupply()                          //
  // ===================================================================== //

  function test_scaledTotalSupply() external {
    vault.scaledTotalSupply();
  }

  // ===================================================================== //
  //                       scaledBalanceOf(address)                        //
  // ===================================================================== //

  function test_scaledBalanceOf(address account) external {
    vault.scaledBalanceOf(account);
  }

  function test_scaledBalanceOf() external {
    address account;
    vault.scaledBalanceOf(account);
  }

  // ===================================================================== //
  //                        effectiveBorrowerAPR()                         //
  // ===================================================================== //

  function test_effectiveBorrowerAPR() external {
    assertEq(vault.effectiveBorrowerAPR(), 1.1e26);
    _deposit(alice, 1e18);
    _borrow(8e17);
    _requestWithdrawal(alice, 1e18);
    assertEq(vault.effectiveBorrowerAPR(), 1.1e26);
    fastForward(2_001);
    assertEq(vault.effectiveBorrowerAPR(), 2.1e26);
  }

  // ===================================================================== //
  //                         effectiveLenderAPR()                          //
  // ===================================================================== //

  function test_effectiveLenderAPR() external {
    assertEq(vault.effectiveLenderAPR(), 1e26);
    _deposit(alice, 1e18);
    _borrow(8e17);
    _requestWithdrawal(alice, 1e18);
    assertEq(vault.effectiveLenderAPR(), 1e26);
    fastForward(2_001);
    assertEq(vault.effectiveLenderAPR(), 2e26);
  }

  // ===================================================================== //
  //                      withdrawableProtocolFees()                       //
  // ===================================================================== //

  function test_withdrawableProtocolFees() external {
    assertEq(vault.withdrawableProtocolFees(), 0);
    _deposit(alice, 1e18);
    fastForward(365 days);
    assertEq(vault.withdrawableProtocolFees(), 1e16);
  }

  function test_withdrawableProtocolFees_LessNormalizedUnclaimedWithdrawals() external {
    assertEq(vault.withdrawableProtocolFees(), 0);
    _deposit(alice, 1e18);
    _borrow(8e17);
    fastForward(365 days);
    _requestWithdrawal(alice, 1e18);
    assertEq(vault.withdrawableProtocolFees(), 1e16);
    asset.mint(address(vault), 8e17 + 1);
    assertEq(vault.withdrawableProtocolFees(), 1e16);
  }
}
