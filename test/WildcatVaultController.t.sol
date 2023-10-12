// SPDX-License-Identifier: NONE
pragma solidity >=0.8.20;

import './BaseVaultTest.sol';
import 'src/interfaces/IVaultEventsAndErrors.sol';
import 'src/libraries/MathUtils.sol';
import 'src/libraries/SafeCastLib.sol';
import 'src/libraries/VaultState.sol';
import 'solady/utils/SafeTransferLib.sol';

contract WildcatVaultControllerTest is BaseVaultTest, IWildcatVaultControllerEventsAndErrors {
  function _check(
    uint256 apr,
    uint256 reserveRatio,
    uint256 cachedReserveRatio,
    uint256 tmpExpiry
  ) internal {
    (uint256 reserveRatioBips, uint256 expiry) = controller.temporaryExcessReserveRatio(
      address(vault)
    );

    assertEq(vault.annualInterestBips(), apr, 'APR');
    assertEq(vault.reserveRatioBips(), reserveRatio, 'reserve ratio');

    assertEq(reserveRatioBips, cachedReserveRatio, 'Previous reserve ratio');
    assertEq(expiry, tmpExpiry, 'Temporary reserve ratio expiry');
  }

  function test_getParameterConstraints() public {
    VaultParameterConstraints memory constraints = controller.getParameterConstraints();
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

  function _callDeployVault(address from) internal asAccount(from) returns (address vaultAddress) {
    vaultAddress = controller.deployVault(
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
    if (vaultAddress != address(0)) {
      assertTrue(controller.isControlledVault(vaultAddress), 'controller does not recognize vault');
      assertTrue(
        archController.isRegisteredVault(vaultAddress),
        'arch controller does not recognize vault'
      );
    }
  }

  function test_VaultSet() external {
    address asset2 = address(new MockERC20('nam', 'sym', 18));

    address[] memory vaults = new address[](2);
    vaults[0] = address(vault);
    vaults[1] = controller.computeVaultAddress(
      asset2,
      parameters.namePrefix,
      parameters.symbolPrefix
    );
    parameters.asset = asset2;
    _callDeployVault(borrower);

    assertEq(controller.getControlledVaults(), vaults, 'getControlledVaults');
    address[] memory vaultSlice = new address[](1);

    vaultSlice[0] = vaults[0];
    assertEq(controller.getControlledVaults(0, 1), vaultSlice, 'getControlledVaults(start, end)');

    vaultSlice[0] = vaults[1];
    assertEq(controller.getControlledVaults(1, 2), vaultSlice, 'getControlledVaults(start, end)');

    assertTrue(controller.isControlledVault(vaults[0]), 'isControlledVault');
    assertTrue(controller.isControlledVault(vaults[1]), 'isControlledVault');

    assertEq(controller.getControlledVaultsCount(), 2, 'getControlledVaultsCount');

    assertEq(archController.getRegisteredVaults(), vaults, 'getRegisteredVaults');
  }

  function test_deployVault_OriginationFee() external {
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
    _callDeployVault(borrower);
  }

  function test_deployVault_AnnualInterestBipsOutOfBounds() external {
    parameters.annualInterestBips = MaximumAnnualInterestBips + 1;
    vm.expectRevert(AnnualInterestBipsOutOfBounds.selector);
    _callDeployVault(borrower);
  }

  function test_deployVault_DelinquencyFeeBipsOutOfBounds() external {
    parameters.delinquencyFeeBips = MaximumDelinquencyFeeBips + 1;
    vm.expectRevert(DelinquencyFeeBipsOutOfBounds.selector);
    _callDeployVault(borrower);
  }

  function test_deployVault_WithdrawalBatchDurationOutOfBounds() external {
    parameters.withdrawalBatchDuration = MaximumWithdrawalBatchDuration + 1;
    vm.expectRevert(WithdrawalBatchDurationOutOfBounds.selector);
    _callDeployVault(borrower);
  }

  function test_deployVault_ReserveRatioBipsOutOfBounds() external {
    parameters.reserveRatioBips = MaximumReserveRatioBips + 1;
    vm.expectRevert(ReserveRatioBipsOutOfBounds.selector);
    _callDeployVault(borrower);
  }

  function test_deployVault_DelinquencyGracePeriodOutOfBounds() external {
    parameters.delinquencyGracePeriod = MaximumDelinquencyGracePeriod + 1;
    vm.expectRevert(DelinquencyGracePeriodOutOfBounds.selector);
    _callDeployVault(borrower);
  }

  function test_deployVault_EmptyString() external {
    parameters.namePrefix = '';
    vm.expectRevert(EmptyString.selector);
    _callDeployVault(borrower);
    parameters.namePrefix = 'Wildcat ';
    parameters.symbolPrefix = '';
    vm.expectRevert(EmptyString.selector);
    _callDeployVault(borrower);
  }

  function test_deployVault_CallerNotBorrowerOrControllerFactory() external {
    vm.expectRevert(CallerNotBorrowerOrControllerFactory.selector);
    _callDeployVault(address(this));
  }

  function test_deployVault_NotRegisteredBorrower() external {
    archController.removeBorrower(borrower);
    vm.expectRevert(NotRegisteredBorrower.selector);
    _callDeployVault(borrower);
  }

  function test_deployVault_BorrowerNotCheckedWhenCalledByFactory() external {
    archController.removeBorrower(borrower);
    parameters.asset = address(new MockERC20('Token', 'TKN', 18));
    assertEq(
      _callDeployVault(address(controllerFactory)),
      controller.computeVaultAddress(
        parameters.asset,
        parameters.namePrefix,
        parameters.symbolPrefix
      )
    );
  }

  function test_deployVault_VaultAlreadyDeployed() external {
    vm.expectRevert(VaultAlreadyDeployed.selector);
    _callDeployVault(borrower);
  }

  /* -------------------------------------------------------------------------- */
  /*                             Vault Control Tests                            */
  /* -------------------------------------------------------------------------- */

  function test_setAnnualInterestBips_NotControlledVault() public {
    vm.prank(borrower);
    vm.expectRevert(NotControlledVault.selector);
    controller.setAnnualInterestBips(address(1), DefaultInterest + 1);
  }

  function test_setAnnualInterestBips_CallerNotBorrower() public {
    vm.expectRevert(CallerNotBorrower.selector);
    controller.setAnnualInterestBips(address(vault), DefaultInterest + 1);
  }

  function test_setAnnualInterestBips_Decrease() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(vault), DefaultInterest - 1);
    _check(DefaultInterest - 1, 9000, DefaultReserveRatio, block.timestamp + 2 weeks);
  }

  function test_setAnnualInterestBips_Decrease_AlreadyPending() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(vault), DefaultInterest - 1);

    uint256 expiry = block.timestamp + 2 weeks;
    _check(DefaultInterest - 1, 9000, DefaultReserveRatio, expiry);

    fastForward(2 weeks);
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(vault), DefaultInterest - 2);
    _check(DefaultInterest - 2, 9000, DefaultReserveRatio, expiry + 2 weeks);
  }

  function test_setAnnualInterestBips_Decrease_Undercollateralized() public {
    _deposit(alice, 50_000e18);
    vm.prank(borrower);
    vault.borrow(5_000e18 + 1);

    vm.startPrank(borrower);
    vm.expectRevert(IVaultEventsAndErrors.InsufficientReservesForNewLiquidityRatio.selector);
    controller.setAnnualInterestBips(address(vault), DefaultInterest - 1);
  }

  function test_setAnnualInterestBips_Increase() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(vault), DefaultInterest + 1);

    _check(DefaultInterest + 1, DefaultReserveRatio, 0, 0);
  }

  function test_setAnnualInterestBips_Increase_Undercollateralized() public {
    _deposit(alice, 50_000e18);
    vm.prank(borrower);
    vault.borrow(5_000e18 + 1);

    vm.prank(borrower);
    controller.setAnnualInterestBips(address(vault), DefaultInterest + 1);
  }

  function test_resetReserveRatio_NotPending() public {
    vm.expectRevert(AprChangeNotPending.selector);
    controller.resetReserveRatio(address(vault));
  }

  function test_resetReserveRatio_StillActive() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(vault), DefaultInterest - 1);

    vm.expectRevert(ExcessReserveRatioStillActive.selector);
    controller.resetReserveRatio(address(vault));
  }

  function test_resetReserveRatio() public {
    vm.prank(borrower);
    controller.setAnnualInterestBips(address(vault), DefaultInterest - 1);

    fastForward(2 weeks);
    controller.resetReserveRatio(address(vault));

    assertEq(vault.reserveRatioBips(), DefaultReserveRatio, 'reserve ratio not reset');

    _check(DefaultInterest - 1, DefaultReserveRatio, 0, 0);
  }
}
