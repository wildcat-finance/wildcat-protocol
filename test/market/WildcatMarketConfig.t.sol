// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'src/interfaces/IVaultEventsAndErrors.sol';
import '../BaseVaultTest.sol';

contract WildcatMarketConfigTest is BaseVaultTest {
  function test_maximumDeposit(uint256 _depositAmount) external returns (uint256) {
    assertEq(vault.maximumDeposit(), parameters.maxTotalSupply);
    _depositAmount = bound(_depositAmount, 1, DefaultMaximumSupply);
    _deposit(alice, _depositAmount);
    assertEq(vault.maximumDeposit(), DefaultMaximumSupply - _depositAmount);
  }

  function test_maximumDeposit_SupplyExceedsMaximum() external returns (uint256) {
    _deposit(alice, parameters.maxTotalSupply);
    fastForward(365 days);
    assertEq(vault.totalSupply(), 110_000e18);
    assertEq(vault.maximumDeposit(), 0);
  }

  function test_maxTotalSupply() external returns (uint256) {
    assertEq(vault.maxTotalSupply(), parameters.maxTotalSupply);
    vm.prank(parameters.controller);
    vault.setMaxTotalSupply(10000);
    assertEq(vault.maxTotalSupply(), 10000);
  }

  function test_annualInterestBips() external returns (uint256) {
    assertEq(vault.annualInterestBips(), parameters.annualInterestBips);
    vm.prank(parameters.controller);
    vault.setAnnualInterestBips(10000);
    assertEq(vault.annualInterestBips(), 10000);
  }

  function test_reserveRatioBips() external returns (uint256) {}

  // function test_revokeAccountAuthorization(
  //   address _account
  // ) external asAccount(parameters.controller) {
  //   vm.expectEmit(address(vault));
  //   emit AuthorizationStatusUpdated(_account, AuthRole.WithdrawOnly);
  //   vault.revokeAccountAuthorization(_account);
  //   assertEq(
  //     uint(vault.getAccountRole(_account)),
  //     uint(AuthRole.WithdrawOnly),
  //     'account role should be WithdrawOnly'
  //   );
  // }

  // function test_revokeAccountAuthorization_NotController(address _account) external {
  //   vm.expectRevert(IVaultEventsAndErrors.NotController.selector);
  //   vault.revokeAccountAuthorization(_account);
  // }

  // function test_revokeAccountAuthorization_AccountBlacklisted(address _account) external {
  //   MockSanctionsSentinel(sentinel).sanction(_account);
  //   vault.nukeFromOrbit(_account);
  //   vm.startPrank(parameters.controller);
  //   vm.expectRevert(IVaultEventsAndErrors.AccountBlacklisted.selector);
  //   vault.revokeAccountAuthorization(_account);
  // }

  // function test_grantAccountAuthorization(
  //   address _account
  // ) external asAccount(parameters.controller) {
  //   vm.expectEmit(address(vault));
  //   emit AuthorizationStatusUpdated(_account, AuthRole.DepositAndWithdraw);
  //   vault.grantAccountAuthorization(_account);
  //   assertEq(
  //     uint(vault.getAccountRole(_account)),
  //     uint(AuthRole.DepositAndWithdraw),
  //     'account role should be DepositAndWithdraw'
  //   );
  // }

  // function test_grantAccountAuthorization_NotController(address _account) external {
  //   vm.expectRevert(IVaultEventsAndErrors.NotController.selector);
  //   vault.grantAccountAuthorization(_account);
  // }

  // function test_grantAccountAuthorization_AccountBlacklisted(address _account) external {
  //   MockSanctionsSentinel(sentinel).sanction(_account);
  //   vault.nukeFromOrbit(_account);
  //   vm.startPrank(parameters.controller);
  //   vm.expectRevert(IVaultEventsAndErrors.AccountBlacklisted.selector);
  //   vault.grantAccountAuthorization(_account);
  // }

  function test_nukeFromOrbit(address _account) external {
    sanctionsSentinel.sanction(_account);

    vm.expectEmit(address(vault));
    emit AuthorizationStatusUpdated(_account, AuthRole.Blocked);
    vault.nukeFromOrbit(_account);
    assertEq(
      uint(vault.getAccountRole(_account)),
      uint(AuthRole.Blocked),
      'account role should be Blocked'
    );
  }

  function test_nukeFromOrbit_WithBalance() external {
    _deposit(alice, 1e18);
    address escrow = sanctionsSentinel.getEscrowAddress(alice, borrower, address(vault));
    sanctionsSentinel.sanction(alice);

    vm.expectEmit(address(vault));
    emit AuthorizationStatusUpdated(alice, AuthRole.Blocked);
    vm.expectEmit(address(vault));
    emit Transfer(alice, escrow, 1e18);
    vm.expectEmit(address(vault));
    emit SanctionedAccountAssetsSentToEscrow(alice, escrow, 1e18);
    vault.nukeFromOrbit(alice);
    assertEq(
      uint(vault.getAccountRole(alice)),
      uint(AuthRole.Blocked),
      'account role should be Blocked'
    );
  }

  function test_nukeFromOrbit_BadLaunchCode(address _account) external {
    vm.expectRevert(IVaultEventsAndErrors.BadLaunchCode.selector);
    vault.nukeFromOrbit(_account);
  }

  function test_stunningReversal() external {
    sanctionsSentinel.sanction(alice);

    vm.expectEmit(address(vault));
    emit AuthorizationStatusUpdated(alice, AuthRole.Blocked);
    vault.nukeFromOrbit(alice);

    vm.prank(borrower);
    sanctionsSentinel.overrideSanction(alice);

    vm.expectEmit(address(vault));
    emit AuthorizationStatusUpdated(alice, AuthRole.Null);
    vault.stunningReversal(alice);
    assertEq(uint(vault.getAccountRole(alice)), uint(AuthRole.Null), 'account role should be Null');
  }

  function test_stunningReversal_AccountNotBlocked(address _account) external {
    vm.expectRevert(IVaultEventsAndErrors.AccountNotBlocked.selector);
    vault.stunningReversal(_account);
  }

  function test_stunningReversal_NotReversedOrStunning() external {
    sanctionsSentinel.sanction(alice);
    vm.expectEmit(address(vault));
    emit AuthorizationStatusUpdated(alice, AuthRole.Blocked);
    vault.nukeFromOrbit(alice);
    vm.expectRevert(IVaultEventsAndErrors.NotReversedOrStunning.selector);
    vault.stunningReversal(alice);
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
    vault.setMaxTotalSupply(_maxTotalSupply);
    assertEq(vault.maxTotalSupply(), _maxTotalSupply, 'maxTotalSupply should be _maxTotalSupply');
  }

  function test_setMaxTotalSupply_NotController(uint128 _maxTotalSupply) external {
    vm.expectRevert(IVaultEventsAndErrors.NotController.selector);
    vault.setMaxTotalSupply(_maxTotalSupply);
  }

  function test_setMaxTotalSupply_NewMaxSupplyTooLow(
    uint256 _totalSupply,
    uint256 _maxTotalSupply
  ) external asAccount(parameters.controller) {
    _totalSupply = bound(_totalSupply, 1, DefaultMaximumSupply - 1);
    _maxTotalSupply = bound(_maxTotalSupply, 0, _totalSupply - 1);
    _deposit(alice, _totalSupply);
    vm.expectRevert(IVaultEventsAndErrors.NewMaxSupplyTooLow.selector);
    vault.setMaxTotalSupply(_maxTotalSupply);
  }

  function test_setAnnualInterestBips(
    uint16 _annualInterestBips
  ) external asAccount(parameters.controller) {
    _annualInterestBips = uint16(bound(_annualInterestBips, 0, 10000));
    vault.setAnnualInterestBips(_annualInterestBips);
    assertEq(vault.annualInterestBips(), _annualInterestBips);
  }

  function test_setAnnualInterestBips_InterestRateTooHigh()
    external
    asAccount(parameters.controller)
  {
    vm.expectRevert(IVaultEventsAndErrors.InterestRateTooHigh.selector);
    vault.setAnnualInterestBips(10001);
  }

  function test_setAnnualInterestBips_NotController(uint16 _annualInterestBips) external {
    vm.expectRevert(IVaultEventsAndErrors.NotController.selector);
    vault.setAnnualInterestBips(_annualInterestBips);
  }

  function test_setReserveRatioBips(
    uint256 _reserveRatioBips
  ) external asAccount(parameters.controller) {
    _reserveRatioBips = bound(_reserveRatioBips, 0, 10000);
    vault.setReserveRatioBips(uint16(_reserveRatioBips));
    assertEq(vault.reserveRatioBips(), _reserveRatioBips);
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
		vm.expectEmit(address(vault));
		emit ReserveRatioBipsUpdated(uint16(_reserveRatioBips));
		vault.setReserveRatioBips(uint16(_reserveRatioBips));
		assertEq(vault.reserveRatioBips(), _reserveRatioBips);
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
    vm.expectRevert(IVaultEventsAndErrors.ReserveRatioBipsTooHigh.selector);
    vault.setReserveRatioBips(10001);
  }

  // Vault already deliquent, LCR set to lower value
  function test_setReserveRatioBips_InsufficientReservesForOldLiquidityRatio()
    external
    asAccount(parameters.controller)
  {
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    vm.expectRevert(IVaultEventsAndErrors.InsufficientReservesForOldLiquidityRatio.selector);
    vault.setReserveRatioBips(1000);
  }

  function test_setReserveRatioBips_InsufficientReservesForNewLiquidityRatio()
    external
    asAccount(parameters.controller)
  {
    _deposit(alice, 1e18);
    _borrow(7e17);
    vm.expectRevert(IVaultEventsAndErrors.InsufficientReservesForNewLiquidityRatio.selector);
    vault.setReserveRatioBips(3001);
  }

  function test_setReserveRatioBips_NotController(uint16 _reserveRatioBips) external {
    vm.expectRevert(IVaultEventsAndErrors.NotController.selector);
    vault.setReserveRatioBips(_reserveRatioBips);
  }
}
