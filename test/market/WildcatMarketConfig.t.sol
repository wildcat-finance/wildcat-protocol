// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'src/interfaces/IMarketEventsAndErrors.sol';
import '../BaseMarketTest.sol';

contract WildcatMarketConfigTest is BaseMarketTest {
  function test_maximumDeposit(uint256 _depositAmount) external returns (uint256) {
    assertEq(market.maximumDeposit(), parameters.maxTotalSupply);
    _depositAmount = bound(_depositAmount, 1, DefaultMaximumSupply);
    _deposit(alice, _depositAmount);
    assertEq(market.maximumDeposit(), DefaultMaximumSupply - _depositAmount);
  }

  function test_maximumDeposit_SupplyExceedsMaximum() external returns (uint256) {
    _deposit(alice, parameters.maxTotalSupply);
    fastForward(365 days);
    assertEq(market.totalSupply(), 110_000e18);
    assertEq(market.maximumDeposit(), 0);
  }

  function test_maxTotalSupply() external returns (uint256) {
    assertEq(market.maxTotalSupply(), parameters.maxTotalSupply);
    vm.prank(parameters.controller);
    market.setMaxTotalSupply(10000);
    assertEq(market.maxTotalSupply(), 10000);
  }

  function test_annualInterestBips() external returns (uint256) {
    assertEq(market.annualInterestBips(), parameters.annualInterestBips);
    vm.prank(parameters.controller);
    market.setAnnualInterestBips(10000);
    assertEq(market.annualInterestBips(), 10000);
  }

  function test_reserveRatioBips() external returns (uint256) {}

  // function test_revokeAccountAuthorization(
  //   address _account
  // ) external asAccount(parameters.controller) {
  //   vm.expectEmit(address(market));
  //   emit AuthorizationStatusUpdated(_account, AuthRole.WithdrawOnly);
  //   market.revokeAccountAuthorization(_account);
  //   assertEq(
  //     uint(market.getAccountRole(_account)),
  //     uint(AuthRole.WithdrawOnly),
  //     'account role should be WithdrawOnly'
  //   );
  // }

  // function test_revokeAccountAuthorization_NotController(address _account) external {
  //   vm.expectRevert(IMarketEventsAndErrors.NotController.selector);
  //   market.revokeAccountAuthorization(_account);
  // }

  // function test_revokeAccountAuthorization_AccountBlacklisted(address _account) external {
  //   MockSanctionsSentinel(sentinel).sanction(_account);
  //   market.nukeFromOrbit(_account);
  //   vm.startPrank(parameters.controller);
  //   vm.expectRevert(IMarketEventsAndErrors.AccountBlacklisted.selector);
  //   market.revokeAccountAuthorization(_account);
  // }

  // function test_grantAccountAuthorization(
  //   address _account
  // ) external asAccount(parameters.controller) {
  //   vm.expectEmit(address(market));
  //   emit AuthorizationStatusUpdated(_account, AuthRole.DepositAndWithdraw);
  //   market.grantAccountAuthorization(_account);
  //   assertEq(
  //     uint(market.getAccountRole(_account)),
  //     uint(AuthRole.DepositAndWithdraw),
  //     'account role should be DepositAndWithdraw'
  //   );
  // }

  // function test_grantAccountAuthorization_NotController(address _account) external {
  //   vm.expectRevert(IMarketEventsAndErrors.NotController.selector);
  //   market.grantAccountAuthorization(_account);
  // }

  // function test_grantAccountAuthorization_AccountBlacklisted(address _account) external {
  //   MockSanctionsSentinel(sentinel).sanction(_account);
  //   market.nukeFromOrbit(_account);
  //   vm.startPrank(parameters.controller);
  //   vm.expectRevert(IMarketEventsAndErrors.AccountBlacklisted.selector);
  //   market.grantAccountAuthorization(_account);
  // }

  function test_nukeFromOrbit(address _account) external {
    sanctionsSentinel.sanction(_account);

    vm.expectEmit(address(market));
    emit AuthorizationStatusUpdated(_account, AuthRole.Blocked);
    market.nukeFromOrbit(_account);
    assertEq(
      uint(market.getAccountRole(_account)),
      uint(AuthRole.Blocked),
      'account role should be Blocked'
    );
  }

  function test_nukeFromOrbit_WithBalance() external {
    _deposit(alice, 1e18);
    address escrow = sanctionsSentinel.getEscrowAddress(alice, borrower, address(market));
    sanctionsSentinel.sanction(alice);

    vm.expectEmit(address(market));
    emit AuthorizationStatusUpdated(alice, AuthRole.Blocked);
    vm.expectEmit(address(market));
    emit Transfer(alice, escrow, 1e18);
    vm.expectEmit(address(market));
    emit SanctionedAccountAssetsSentToEscrow(alice, escrow, 1e18);
    market.nukeFromOrbit(alice);
    assertEq(
      uint(market.getAccountRole(alice)),
      uint(AuthRole.Blocked),
      'account role should be Blocked'
    );
  }

  function test_nukeFromOrbit_BadLaunchCode(address _account) external {
    vm.expectRevert(IMarketEventsAndErrors.BadLaunchCode.selector);
    market.nukeFromOrbit(_account);
  }

  function test_stunningReversal() external {
    sanctionsSentinel.sanction(alice);

    vm.expectEmit(address(market));
    emit AuthorizationStatusUpdated(alice, AuthRole.Blocked);
    market.nukeFromOrbit(alice);

    vm.prank(borrower);
    sanctionsSentinel.overrideSanction(alice);

    vm.expectEmit(address(market));
    emit AuthorizationStatusUpdated(alice, AuthRole.Null);
    market.stunningReversal(alice);
    assertEq(uint(market.getAccountRole(alice)), uint(AuthRole.Null), 'account role should be Null');
  }

  function test_stunningReversal_AccountNotBlocked(address _account) external {
    vm.expectRevert(IMarketEventsAndErrors.AccountNotBlocked.selector);
    market.stunningReversal(_account);
  }

  function test_stunningReversal_NotReversedOrStunning() external {
    sanctionsSentinel.sanction(alice);
    vm.expectEmit(address(market));
    emit AuthorizationStatusUpdated(alice, AuthRole.Blocked);
    market.nukeFromOrbit(alice);
    vm.expectRevert(IMarketEventsAndErrors.NotReversedOrStunning.selector);
    market.stunningReversal(alice);
  }

  function test_setMaxTotalSupply(
    uint256 _totalSupply,
    uint256 _maxTotalSupply
  ) external asAccount(parameters.controller) {
    _totalSupply = bound(_totalSupply, 0, DefaultMaximumSupply);
    _maxTotalSupply = bound(_maxTotalSupply, _totalSupply, type(uint128).max);
    if (_totalSupply > 0) {
      _deposit(alice, _totalSupply);
    }
    market.setMaxTotalSupply(_maxTotalSupply);
    assertEq(market.maxTotalSupply(), _maxTotalSupply, 'maxTotalSupply should be _maxTotalSupply');
  }

  function test_setMaxTotalSupply_NotController(uint128 _maxTotalSupply) external {
    vm.expectRevert(IMarketEventsAndErrors.NotController.selector);
    market.setMaxTotalSupply(_maxTotalSupply);
  }

  function test_setMaxTotalSupply_NewMaxSupplyTooLow(
    uint256 _totalSupply,
    uint256 _maxTotalSupply
  ) external asAccount(parameters.controller) {
    _totalSupply = bound(_totalSupply, 1, DefaultMaximumSupply - 1);
    _maxTotalSupply = bound(_maxTotalSupply, 0, _totalSupply - 1);
    _deposit(alice, _totalSupply);
    vm.expectRevert(IMarketEventsAndErrors.NewMaxSupplyTooLow.selector);
    market.setMaxTotalSupply(_maxTotalSupply);
  }

  function test_setAnnualInterestBips(
    uint16 _annualInterestBips
  ) external asAccount(parameters.controller) {
    _annualInterestBips = uint16(bound(_annualInterestBips, 0, 10000));
    market.setAnnualInterestBips(_annualInterestBips);
    assertEq(market.annualInterestBips(), _annualInterestBips);
  }

  function test_setAnnualInterestBips_InterestRateTooHigh()
    external
    asAccount(parameters.controller)
  {
    vm.expectRevert(IMarketEventsAndErrors.InterestRateTooHigh.selector);
    market.setAnnualInterestBips(10001);
  }

  function test_setAnnualInterestBips_NotController(uint16 _annualInterestBips) external {
    vm.expectRevert(IMarketEventsAndErrors.NotController.selector);
    market.setAnnualInterestBips(_annualInterestBips);
  }

  function test_setReserveRatioBips(
    uint256 _reserveRatioBips
  ) external asAccount(parameters.controller) {
    _reserveRatioBips = bound(_reserveRatioBips, 0, 10000);
    market.setReserveRatioBips(uint16(_reserveRatioBips));
    assertEq(market.reserveRatioBips(), _reserveRatioBips);
  }

  /* 	function test_setReserveRatioBips_IncreaseWhileDelinquent(
		uint256 _reserveRatioBips
	) external asAccount(parameters.controller) {
		_reserveRatioBips = bound(
			_reserveRatioBips,
			parameters.reserveRatioBips + 1,
			10000
		);
		_induceDelinquency();
		vm.expectEmit(address(market));
		emit ReserveRatioBipsUpdated(uint16(_reserveRatioBips));
		market.setReserveRatioBips(uint16(_reserveRatioBips));
		assertEq(market.reserveRatioBips(), _reserveRatioBips);
	} */

  function _induceDelinquency() internal {
    _deposit(alice, 1e18);
    _borrow(2e17);
    _requestWithdrawal(alice, 9e17);
  }

  function test_setReserveRatioBips_ReserveRatioBipsTooHigh()
    external
    asAccount(parameters.controller)
  {
    vm.expectRevert(IMarketEventsAndErrors.ReserveRatioBipsTooHigh.selector);
    market.setReserveRatioBips(10001);
  }

  // Market already deliquent, LCR set to lower value
  function test_setReserveRatioBips_InsufficientReservesForOldLiquidityRatio()
    external
    asAccount(parameters.controller)
  {
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    vm.expectRevert(IMarketEventsAndErrors.InsufficientReservesForOldLiquidityRatio.selector);
    market.setReserveRatioBips(1000);
  }

  function test_setReserveRatioBips_InsufficientReservesForNewLiquidityRatio()
    external
    asAccount(parameters.controller)
  {
    _deposit(alice, 1e18);
    _borrow(7e17);
    vm.expectRevert(IMarketEventsAndErrors.InsufficientReservesForNewLiquidityRatio.selector);
    market.setReserveRatioBips(3001);
  }

  function test_setReserveRatioBips_NotController(uint16 _reserveRatioBips) external {
    vm.expectRevert(IMarketEventsAndErrors.NotController.selector);
    market.setReserveRatioBips(_reserveRatioBips);
  }
}
