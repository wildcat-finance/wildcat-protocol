// SPDX-License-Identifier: NONE
pragma solidity >=0.8.20;

import './BaseMarketTest.sol';
import 'src/interfaces/IMarketEventsAndErrors.sol';
import 'src/libraries/MathUtils.sol';
import 'src/libraries/SafeCastLib.sol';
import 'src/libraries/MarketState.sol';
import 'solady/utils/SafeTransferLib.sol';

contract WildcatMarketControllerTest is BaseMarketTest {
  function _check(
    uint256 annualInterestBips,
    uint256 originalAnnualInterestBips,
    uint256 reserveRatioBips,
    uint256 originalReserveRatioBips,
    uint256 temporaryReserveRatioExpiry
  ) internal {
    (
      uint256 _originalAnnualInterestBips,
      uint256 _originalReserveRatioBips,
      uint256 expiry
    ) = controller.temporaryExcessReserveRatio(address(market));

    assertEq(market.annualInterestBips(), annualInterestBips, 'annualInterestBips');
    assertEq(market.reserveRatioBips(), reserveRatioBips, 'reserveRatioBips');

    assertEq(_originalAnnualInterestBips, originalAnnualInterestBips, 'originalAnnualInterestBips');
    assertEq(_originalReserveRatioBips, originalReserveRatioBips, 'originalReserveRatioBips');
    assertEq(expiry, temporaryReserveRatioExpiry, 'temporaryReserveRatioExpiry');
  }

  function test_getParameterConstraints() public {
    MarketParameterConstraints memory constraints = controller.getParameterConstraints();
    assertEq(
      constraints.minimumDelinquencyGracePeriod,
      MinimumDelinquencyGracePeriod,
      'minimumDelinquencyGracePeriod'
    );
    assertEq(
      constraints.maximumDelinquencyGracePeriod,
      MaximumDelinquencyGracePeriod,
      'maximumDelinquencyGracePeriod'
    );
    assertEq(
      constraints.minimumReserveRatioBips,
      MinimumReserveRatioBips,
      'minimumReserveRatioBips'
    );
    assertEq(
      constraints.maximumReserveRatioBips,
      MaximumReserveRatioBips,
      'maximumReserveRatioBips'
    );
    assertEq(
      constraints.minimumDelinquencyFeeBips,
      MinimumDelinquencyFeeBips,
      'minimumDelinquencyFeeBips'
    );
    assertEq(
      constraints.maximumDelinquencyFeeBips,
      MaximumDelinquencyFeeBips,
      'maximumDelinquencyFeeBips'
    );
    assertEq(
      constraints.minimumWithdrawalBatchDuration,
      MinimumWithdrawalBatchDuration,
      'minimumWithdrawalBatchDuration'
    );
    assertEq(
      constraints.maximumWithdrawalBatchDuration,
      MaximumWithdrawalBatchDuration,
      'maximumWithdrawalBatchDuration'
    );
    assertEq(
      constraints.minimumAnnualInterestBips,
      MinimumAnnualInterestBips,
      'minimumAnnualInterestBips'
    );
    assertEq(
      constraints.maximumAnnualInterestBips,
      MaximumAnnualInterestBips,
      'maximumAnnualInterestBips'
    );
  }

  function _getLenders() internal view returns (address[] memory lenders) {
    lenders = new address[](4);
    lenders[0] = address(1);
    lenders[1] = address(2);
    lenders[2] = address(1);
    lenders[3] = address(3);
  }

  function test_authorizeLenders() external asAccount(borrower) {
    _deauthorizeLender(alice);
    address[] memory lenders = _getLenders();
    vm.expectEmit(address(controller));
    emit LenderAuthorized(address(1));
    vm.expectEmit(address(controller));
    emit LenderAuthorized(address(2));
    vm.expectEmit(address(controller));
    emit LenderAuthorized(address(3));
    controller.authorizeLenders(lenders);
    lenders[2] = address(3);
    assembly {
      mstore(lenders, 3)
    }
    assertEq(controller.getAuthorizedLenders(), lenders, 'getAuthorizedLenders');
    address[] memory lenderSlice = new address[](2);
    lenderSlice[0] = address(1);
    lenderSlice[1] = address(2);
    assertEq(
      controller.getAuthorizedLenders(0, 2),
      lenderSlice,
      'getAuthorizedLenders(start, end)'
    );
    assertEq(controller.getAuthorizedLendersCount(), 3, 'getAuthorizedLendersCount');
    for (uint i = 1; i < 4; i++) {
      assertTrue(controller.isAuthorizedLender(address(uint160(i))), 'isAuthorizedLender');
    }
  }

  function test_deauthorizeLenders() external asAccount(borrower) {
    _deauthorizeLender(alice);
    address[] memory lenders = _getLenders();
    controller.authorizeLenders(lenders);
    vm.expectEmit(address(controller));
    emit LenderDeauthorized(address(1));
    vm.expectEmit(address(controller));
    emit LenderDeauthorized(address(2));
    vm.expectEmit(address(controller));
    emit LenderDeauthorized(address(3));
    controller.deauthorizeLenders(lenders);
    assembly {
      mstore(lenders, 0)
    }
    assertEq(controller.getAuthorizedLenders(), lenders, 'getAuthorizedLenders');
    assertEq(controller.getAuthorizedLenders(0, 2), lenders, 'getAuthorizedLenders(start, end)');
    assertEq(controller.getAuthorizedLendersCount(), 0, 'getAuthorizedLendersCount');
    for (uint i = 1; i < 4; i++) {
      assertFalse(controller.isAuthorizedLender(address(uint160(i))), 'isAuthorizedLender');
    }
  }

  function test_getProtocolFeeConfiguration() external {
    (
      address feeRecipient,
      address originationFeeAsset,
      uint80 originationFeeAmount,
      uint16 protocolFeeBips
    ) = controller.getProtocolFeeConfiguration();
    (
      address _feeRecipient,
      address _originationFeeAsset,
      uint80 _originationFeeAmount,
      uint16 _protocolFeeBips
    ) = controllerFactory.getProtocolFeeConfiguration();
    assertEq(feeRecipient, _feeRecipient, 'feeRecipient');
    assertEq(originationFeeAsset, _originationFeeAsset, 'originationFeeAsset');
    assertEq(originationFeeAmount, _originationFeeAmount, 'originationFeeAmount');
    assertEq(protocolFeeBips, _protocolFeeBips, 'protocolFeeBips');
  }

  function _callDeployMarket(
    address from
  ) internal asAccount(from) returns (address marketAddress) {
    marketAddress = controller.deployMarket(
      parameters.asset,
      parameters.namePrefix,
      parameters.symbolPrefix,
      parameters.maxTotalSupply,
      parameters.annualInterestBips,
      parameters.delinquencyFeeBips,
      parameters.withdrawalBatchDuration,
      parameters.reserveRatioBips,
      parameters.delinquencyGracePeriod
    );
    if (marketAddress != address(0)) {
      assertTrue(
        controller.isControlledMarket(marketAddress),
        'controller does not recognize market'
      );
      assertTrue(
        archController.isRegisteredMarket(marketAddress),
        'arch controller does not recognize market'
      );
    }
  }

  function test_updateLenderAuthorization_NotControlledMarket() external asAccount(borrower) {
    address[] memory markets = new address[](1);
    markets[0] = address(1);
    vm.expectRevert(NotControlledMarket.selector);
    controller.updateLenderAuthorization(address(1), markets);
  }

  function test_updateLenderAuthorization() external asAccount(borrower) {
    address[] memory markets = new address[](1);
    markets[0] = address(market);
    _authorizeLender(bob);
    vm.expectEmit(address(market));
    emit IMarketEventsAndErrors.AuthorizationStatusUpdated(bob, AuthRole.DepositAndWithdraw);
    controller.updateLenderAuthorization(bob, markets);

    _deauthorizeLender(bob);
    vm.expectEmit(address(market));
    emit IMarketEventsAndErrors.AuthorizationStatusUpdated(bob, AuthRole.WithdrawOnly);
    controller.updateLenderAuthorization(bob, markets);
  }

  function test_closeMarket() external asAccount(borrower) {
    vm.expectEmit(address(market));
    emit IMarketEventsAndErrors.MarketClosed(block.timestamp);
    controller.closeMarket(address(market));
  }

  function test_closeMarket_NotBorrower() external {
    vm.expectRevert(CallerNotBorrower.selector);
    controller.closeMarket(address(market));
  }

  function test_closeMarket_NotControlledMarket() external asAccount(borrower) {
    vm.expectRevert(NotControlledMarket.selector);
    controller.closeMarket(address(1));
  }

  function test_closeMarket_MarketAlreadyClosed() external asAccount(borrower) {
    controller.closeMarket(address(market));
    vm.expectRevert(MarketAlreadyClosed.selector);
    controller.closeMarket(address(market));
  }

  function test_setMaxTotalSupply() external asAccount(borrower) {
    vm.expectEmit(address(market));
    emit IMarketEventsAndErrors.MaxTotalSupplyUpdated(1e18);
    controller.setMaxTotalSupply(address(market), 1e18);
  }

  function test_setMaxTotalSupply_NotBorrower() external {
    vm.expectRevert(CallerNotBorrower.selector);
    controller.setMaxTotalSupply(address(market), 0);
  }

  function test_setMaxTotalSupply_NotControlledMarket() external asAccount(borrower) {
    vm.expectRevert(NotControlledMarket.selector);
    controller.setMaxTotalSupply(address(1), 0);
  }

  function test_setMaxTotalSupply_CapacityChangeOnClosedMarket() external asAccount(borrower) {
    controller.closeMarket(address(market));
    vm.expectRevert(CapacityChangeOnClosedMarket.selector);
    controller.setMaxTotalSupply(address(market), 0);
  }

  function test_MarketSet() external {
    address asset2 = address(new MockERC20('nam', 'sym', 18));

    address[] memory markets = new address[](2);
    markets[0] = address(market);
    markets[1] = controller.computeMarketAddress(
      asset2,
      parameters.namePrefix,
      parameters.symbolPrefix
    );
    parameters.asset = asset2;
    _callDeployMarket(borrower);

    assertEq(controller.getControlledMarkets(), markets, 'getControlledMarkets');
    address[] memory marketSlice = new address[](1);

    marketSlice[0] = markets[0];
    assertEq(
      controller.getControlledMarkets(0, 1),
      marketSlice,
      'getControlledMarkets(start, end)'
    );

    marketSlice[0] = markets[1];
    assertEq(
      controller.getControlledMarkets(1, 2),
      marketSlice,
      'getControlledMarkets(start, end)'
    );

    assertTrue(controller.isControlledMarket(markets[0]), 'isControlledMarket');
    assertTrue(controller.isControlledMarket(markets[1]), 'isControlledMarket');

    assertEq(controller.getControlledMarketsCount(), 2, 'getControlledMarketsCount');

    assertEq(archController.getRegisteredMarkets(), markets, 'getRegisteredMarkets');
  }

  function test_deployMarket_OriginationFee() external {
    MockERC20 feeAsset = new MockERC20('', '', 18);
    feeAsset.mint(borrower, 10e18);
    startPrank(borrower);
    feeAsset.approve(address(controller), 10e18);
    stopPrank();
    controllerFactory.setProtocolFeeConfiguration(
      parameters.feeRecipient,
      address(feeAsset),
      10e18,
      parameters.protocolFeeBips
    );
    parameters.asset = address(asset = new MockERC20('Token', 'TKN', 18));
    vm.expectEmit(address(feeAsset));
    emit Transfer(borrower, feeRecipient, 10e18);
    _callDeployMarket(borrower);
  }

  function test_deployMarket_AnnualInterestBipsOutOfBounds() external {
    parameters.annualInterestBips = MaximumAnnualInterestBips + 1;
    vm.expectRevert(AnnualInterestBipsOutOfBounds.selector);
    _callDeployMarket(borrower);
  }

  function test_deployMarket_DelinquencyFeeBipsOutOfBounds() external {
    parameters.delinquencyFeeBips = MaximumDelinquencyFeeBips + 1;
    vm.expectRevert(DelinquencyFeeBipsOutOfBounds.selector);
    _callDeployMarket(borrower);
  }

  function test_deployMarket_WithdrawalBatchDurationOutOfBounds() external {
    parameters.withdrawalBatchDuration = MaximumWithdrawalBatchDuration + 1;
    vm.expectRevert(WithdrawalBatchDurationOutOfBounds.selector);
    _callDeployMarket(borrower);
  }

  function test_deployMarket_ReserveRatioBipsOutOfBounds() external {
    parameters.reserveRatioBips = MaximumReserveRatioBips + 1;
    vm.expectRevert(ReserveRatioBipsOutOfBounds.selector);
    _callDeployMarket(borrower);
  }

  function test_deployMarket_DelinquencyGracePeriodOutOfBounds() external {
    parameters.delinquencyGracePeriod = MaximumDelinquencyGracePeriod + 1;
    vm.expectRevert(DelinquencyGracePeriodOutOfBounds.selector);
    _callDeployMarket(borrower);
  }

  function test_deployMarket_EmptyString() external {
    parameters.namePrefix = '';
    vm.expectRevert(EmptyString.selector);
    _callDeployMarket(borrower);
    parameters.namePrefix = 'Wildcat ';
    parameters.symbolPrefix = '';
    vm.expectRevert(EmptyString.selector);
    _callDeployMarket(borrower);
  }

  function test_deployMarket_CallerNotBorrowerOrControllerFactory() external {
    vm.expectRevert(CallerNotBorrowerOrControllerFactory.selector);
    _callDeployMarket(address(this));
  }

  function test_deployMarket_NotRegisteredBorrower() external {
    archController.removeBorrower(borrower);
    vm.expectRevert(NotRegisteredBorrower.selector);
    _callDeployMarket(borrower);
  }

  function test_deployMarket_BorrowerNotCheckedWhenCalledByFactory() external {
    archController.removeBorrower(borrower);
    parameters.asset = address(new MockERC20('Token', 'TKN', 18));
    assertEq(
      _callDeployMarket(address(controllerFactory)),
      controller.computeMarketAddress(
        parameters.asset,
        parameters.namePrefix,
        parameters.symbolPrefix
      )
    );
  }

  function test_deployMarket_MarketAlreadyDeployed() external {
    vm.expectRevert(MarketAlreadyDeployed.selector);
    _callDeployMarket(borrower);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Market Control Tests                            */
  /* -------------------------------------------------------------------------- */

  function test_setAnnualInterestBips_NotControlledMarket() public {
    vm.prank(borrower);
    vm.expectRevert(NotControlledMarket.selector);
    controller.setAnnualInterestBips(address(1), DefaultInterest + 1);
  }

  function test_setAnnualInterestBips_CallerNotBorrower() public {
    vm.expectRevert(CallerNotBorrower.selector);
    controller.setAnnualInterestBips(address(market), DefaultInterest + 1);
  }

  function test_setAnnualInterestBips_NegligibleDecrease() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), DefaultInterest - 1);
    _check(
      DefaultInterest - 1,
      DefaultInterest,
      DefaultReserveRatio,
      DefaultReserveRatio,
      block.timestamp + 2 weeks
    );
  }

  function test_setAnnualInterestBips_Decrease_Decrease() public {
    uint256 expiry = block.timestamp + 2 weeks;
    vm.expectEmit(address(controller));
    emit TemporaryExcessReserveRatioActivated(address(market), DefaultReserveRatio, 4_000, expiry);
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), 800);

    _check(800, DefaultInterest, 4_000, DefaultReserveRatio, expiry);

    fastForward(1 weeks);

    vm.expectEmit(address(controller));
    emit TemporaryExcessReserveRatioUpdated(
      address(market),
      DefaultReserveRatio,
      6_000,
      expiry + 1 weeks
    );
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), 700);
    _check(700, DefaultInterest, 6_000, DefaultReserveRatio, expiry + 1 weeks);
  }

  function test_setAnnualInterestBips_Decrease_Increase() public {
    uint256 expiry = block.timestamp + 2 weeks;
    vm.expectEmit(address(controller));
    emit TemporaryExcessReserveRatioActivated(address(market), DefaultReserveRatio, 4_000, expiry);
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), 800);

    _check(800, DefaultInterest, 4_000, DefaultReserveRatio, expiry);

    fastForward(1 weeks);

    vm.expectEmit(address(controller));
    emit TemporaryExcessReserveRatioUpdated(address(market), DefaultReserveRatio, 4_000, expiry);
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), 800);
    _check(800, DefaultInterest, 4_000, DefaultReserveRatio, expiry);

    vm.expectEmit(address(controller));
    emit TemporaryExcessReserveRatioUpdated(address(market), DefaultReserveRatio, 3_000, expiry);
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), 850);
    _check(850, DefaultInterest, 3_000, DefaultReserveRatio, expiry);
  }

  function test_setAnnualInterestBips_MaxReserveRatio() public {
    uint256 expiry = block.timestamp + 2 weeks;
    vm.expectEmit(address(controller));
    emit TemporaryExcessReserveRatioActivated(address(market), DefaultReserveRatio, 10_000, expiry);
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), 400);

    _check(400, DefaultInterest, 10_000, DefaultReserveRatio, expiry);
  }

  function test_setAnnualInterestBips_Decrease_Cancel() public {
    uint256 expiry = block.timestamp + 2 weeks;
    vm.expectEmit(address(controller));
    emit TemporaryExcessReserveRatioActivated(address(market), DefaultReserveRatio, 4_000, expiry);
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), 800);

    _check(800, DefaultInterest, 4_000, DefaultReserveRatio, expiry);

    fastForward(1 weeks);

    vm.expectEmit(address(controller));
    emit TemporaryExcessReserveRatioCanceled(address(market));
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), 1_001);
    _check(1_001, 0, DefaultReserveRatio, 0, 0);
  }

  function test_setAnnualInterestBips_Decrease_Undercollateralized() public {
    _deposit(alice, 50_000e18);
    vm.prank(borrower);
    market.borrow(5_000e18 + 1);

    vm.startPrank(borrower);
    vm.expectRevert(IMarketEventsAndErrors.InsufficientReservesForNewLiquidityRatio.selector);
    controller.setAnnualInterestBips(address(market), 550);
  }

  function test_setAnnualInterestBips_AprChangeOnClosedMarket() public asAccount(borrower) {
    controller.closeMarket(address(market));
    vm.expectRevert(AprChangeOnClosedMarket.selector);
    controller.setAnnualInterestBips(address(market), 550);
  }

  function test_setAnnualInterestBips_Increase() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), DefaultInterest + 1);

    _check(DefaultInterest + 1, 0, DefaultReserveRatio, 0, 0);
  }

  function test_setAnnualInterestBips_Increase_Undercollateralized() public {
    _deposit(alice, 50_000e18);
    vm.prank(borrower);
    market.borrow(5_000e18 + 1);

    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), DefaultInterest + 1);
  }

  function test_resetReserveRatio_NotPending() public {
    vm.expectRevert(AprChangeNotPending.selector);
    controller.resetReserveRatio(address(market));
  }

  function test_resetReserveRatio_StillActive() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), DefaultInterest - 1);

    vm.expectRevert(ExcessReserveRatioStillActive.selector);
    controller.resetReserveRatio(address(market));
  }

  function test_resetReserveRatio() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), DefaultInterest - 1);

    _check(
      DefaultInterest - 1,
      DefaultInterest,
      DefaultReserveRatio,
      DefaultReserveRatio,
      block.timestamp + 2 weeks
    );

    fastForward(2 weeks);
    controller.resetReserveRatio(address(market));

    assertEq(market.reserveRatioBips(), DefaultReserveRatio, 'reserve ratio not reset');

    _check(DefaultInterest - 1, 0, DefaultReserveRatio, 0, 0);
  }
}
