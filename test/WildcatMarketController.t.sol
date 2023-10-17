// SPDX-License-Identifier: NONE
pragma solidity >=0.8.20;

import './BaseMarketTest.sol';
import 'src/interfaces/IMarketEventsAndErrors.sol';
import 'src/libraries/MathUtils.sol';
import 'src/libraries/SafeCastLib.sol';
import 'src/libraries/MarketState.sol';
import 'solady/utils/SafeTransferLib.sol';

contract WildcatMarketControllerTest is BaseMarketTest, IWildcatMarketControllerEventsAndErrors {
  function _check(
    uint256 apr,
    uint256 reserveRatio,
    uint256 cachedReserveRatio,
    uint256 tmpExpiry
  ) internal {
    (uint256 reserveRatioBips, uint256 expiry) = controller.temporaryExcessReserveRatio(
      address(market)
    );

    assertEq(market.annualInterestBips(), apr, 'APR');
    assertEq(market.reserveRatioBips(), reserveRatio, 'reserve ratio');

    assertEq(reserveRatioBips, cachedReserveRatio, 'Previous reserve ratio');
    assertEq(expiry, tmpExpiry, 'Temporary reserve ratio expiry');
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
  }

  function _callDeployMarket(address from) internal asAccount(from) returns (address marketAddress) {
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
      assertTrue(controller.isControlledMarket(marketAddress), 'controller does not recognize market');
      assertTrue(
        archController.isRegisteredMarket(marketAddress),
        'arch controller does not recognize market'
      );
    }
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
    assertEq(controller.getControlledMarkets(0, 1), marketSlice, 'getControlledMarkets(start, end)');

    marketSlice[0] = markets[1];
    assertEq(controller.getControlledMarkets(1, 2), marketSlice, 'getControlledMarkets(start, end)');

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

  function test_setAnnualInterestBips_Decrease() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), DefaultInterest - 1);
    _check(DefaultInterest - 1, 9000, DefaultReserveRatio, block.timestamp + 2 weeks);
  }

  function test_setAnnualInterestBips_Decrease_AlreadyPending() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), DefaultInterest - 1);

    uint256 expiry = block.timestamp + 2 weeks;
    _check(DefaultInterest - 1, 9000, DefaultReserveRatio, expiry);

    fastForward(2 weeks);
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), DefaultInterest - 2);
    _check(DefaultInterest - 2, 9000, DefaultReserveRatio, expiry + 2 weeks);
  }

  function test_setAnnualInterestBips_Decrease_Undercollateralized() public {
    _deposit(alice, 50_000e18);
    vm.prank(borrower);
    market.borrow(5_000e18 + 1);

    vm.startPrank(borrower);
    vm.expectRevert(IMarketEventsAndErrors.InsufficientReservesForNewLiquidityRatio.selector);
    controller.setAnnualInterestBips(address(market), DefaultInterest - 1);
  }

  function test_setAnnualInterestBips_Increase() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), DefaultInterest + 1);

    _check(DefaultInterest + 1, DefaultReserveRatio, 0, 0);
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

    fastForward(2 weeks);
    controller.resetReserveRatio(address(market));

    assertEq(market.reserveRatioBips(), DefaultReserveRatio, 'reserve ratio not reset');

    _check(DefaultInterest - 1, DefaultReserveRatio, 0, 0);
  }
}
