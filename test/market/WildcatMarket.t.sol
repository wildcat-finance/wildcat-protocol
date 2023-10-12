// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../BaseVaultTest.sol';
import 'src/interfaces/IVaultEventsAndErrors.sol';
import 'src/libraries/MathUtils.sol';
import 'src/libraries/SafeCastLib.sol';
import 'src/libraries/VaultState.sol';
import 'solady/utils/SafeTransferLib.sol';

contract WildcatMarketTest is BaseVaultTest {
  using stdStorage for StdStorage;
  // using WadRayMath for uint256;
  using MathUtils for int256;
  using MathUtils for uint256;

  // ===================================================================== //
  //                             updateState()                             //
  // ===================================================================== //

  function test_updateState() external {
    _deposit(alice, 1e18);
    fastForward(365 days);
    VaultState memory state = pendingState();
    updateState(state);
    vault.updateState();
    assertEq(vault.previousState(), state);
  }

  function test_updateState_NoChange() external {
    _deposit(alice, 1e18);
    VaultState memory state = pendingState();
    bytes32 stateHash = keccak256(abi.encode(state));
    vault.updateState();
    assertEq(keccak256(abi.encode(vault.previousState())), stateHash);
    assertEq(keccak256(abi.encode(vault.currentState())), stateHash);
  }

  function test_updateState_HasPendingExpiredBatch() external {
    parameters.annualInterestBips = 3650;
    setUp();
    _deposit(alice, 1e18);
    _requestWithdrawal(alice, 1e18);
    uint32 expiry = previousState.pendingWithdrawalExpiry;
    fastForward(1 days);
    VaultState memory state = pendingState();
    vm.expectEmit(address(vault));
    emit ScaleFactorUpdated(1.001e27, 1e24, 0, 0);
    vm.expectEmit(address(vault));
    emit WithdrawalBatchExpired(expiry, 1e18, 1e18, 1e18);
    vm.expectEmit(address(vault));
    emit WithdrawalBatchClosed(expiry);
    vm.expectEmit(address(vault));
    emit StateUpdated(1.001e27, false);
    vault.updateState();
  }

  function test_updateState_HasPendingExpiredBatch_SameBlock() external {
    parameters.withdrawalBatchDuration = 0;
    setUpContracts(true);
    setUp();
    _deposit(alice, 1e18);
    _requestWithdrawal(alice, 1e18);
    VaultState memory state = pendingState();
    vm.expectEmit(address(vault));
    emit WithdrawalBatchExpired(block.timestamp, 1e18, 1e18, 1e18);
    vm.expectEmit(address(vault));
    emit WithdrawalBatchClosed(block.timestamp);
    vm.expectEmit(address(vault));
    emit StateUpdated(1e27, false);
    vault.updateState();
  }

  // ===================================================================== //
  //                         depositUpTo(uint256)                          //
  // ===================================================================== //

  function test_depositUpTo() external asAccount(alice) {
    _deposit(alice, 50_000e18);
    assertEq(vault.totalSupply(), 50_000e18);
    assertEq(vault.balanceOf(alice), 50_000e18);
  }

  function test_depositUpTo(uint256 amount) external asAccount(alice) {
    amount = bound(amount, 1, DefaultMaximumSupply);
    vault.depositUpTo(amount);
  }

  function test_depositUpTo_ApprovedOnController() public asAccount(bob) {
    _authorizeLender(bob);
    vm.expectEmit(address(vault));
    emit AuthorizationStatusUpdated(bob, AuthRole.DepositAndWithdraw);
    vault.depositUpTo(1e18);
    assertEq(uint(vault.getAccountRole(bob)), uint(AuthRole.DepositAndWithdraw));
  }

  function test_depositUpTo_NullMintAmount() external asAccount(alice) {
    vm.expectRevert(IVaultEventsAndErrors.NullMintAmount.selector);
    vault.depositUpTo(0);
  }

  function testDepositUpTo_MaxSupplyExceeded() public asAccount(bob) {
    _authorizeLender(bob);
    asset.transfer(address(1), type(uint128).max);
    asset.mint(bob, DefaultMaximumSupply);
    asset.approve(address(vault), DefaultMaximumSupply);
    vault.depositUpTo(DefaultMaximumSupply - 1);
    vault.depositUpTo(2);
    assertEq(vault.balanceOf(bob), DefaultMaximumSupply);
    assertEq(asset.balanceOf(bob), 0);
  }

  function testDepositUpTo_NotApprovedLender() public asAccount(bob) {
    asset.mint(bob, 1e18);
    asset.approve(address(vault), 1e18);
    vm.expectRevert(IVaultEventsAndErrors.NotApprovedLender.selector);
    vault.depositUpTo(1e18);
  }

  function testDepositUpTo_TransferFail() public asAccount(alice) {
    asset.approve(address(vault), 0);
    vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
    vault.depositUpTo(50_000e18);
  }

  // ===================================================================== //
  //                           deposit(uint256)                            //
  // ===================================================================== //

  function test_deposit(uint256 amount) external asAccount(alice) {
    amount = bound(amount, 1, DefaultMaximumSupply);
    vault.deposit(amount);
  }

  function testDeposit_NotApprovedLender() public asAccount(bob) {
    vm.expectRevert(IVaultEventsAndErrors.NotApprovedLender.selector);
    vault.deposit(1e18);
  }

  function testDeposit_MaxSupplyExceeded() public asAccount(alice) {
    vault.deposit(DefaultMaximumSupply - 1);
    vm.expectRevert(IVaultEventsAndErrors.MaxSupplyExceeded.selector);
    vault.deposit(2);
  }

  // ===================================================================== //
  //                             collectFees()                             //
  // ===================================================================== //

  function test_collectFees_NoFeesAccrued() external {
    vm.expectRevert(IVaultEventsAndErrors.NullFeeAmount.selector);
    vault.collectFees();
  }

  function test_collectFees() external {
    _deposit(alice, 1e18);
    fastForward(365 days);
    vm.expectEmit(address(asset));
    emit Transfer(address(vault), feeRecipient, 1e16);
    vm.expectEmit(address(vault));
    emit FeesCollected(1e16);
    vault.collectFees();
  }

  function test_collectFees_InsufficientReservesForFeeWithdrawal() external {
    _deposit(alice, 1e18);
    fastForward(1);
    asset.burn(address(vault), 1e18);
    vm.expectRevert(IVaultEventsAndErrors.InsufficientReservesForFeeWithdrawal.selector);
    vault.collectFees();
  }

  // ===================================================================== //
  //                            borrow(uint256)                            //
  // ===================================================================== //

  function test_borrow(uint256 amount) external {
    uint256 availableCollateral = vault.borrowableAssets();
    assertEq(availableCollateral, 0, 'borrowable should be 0');

    vm.prank(alice);
    vault.depositUpTo(50_000e18);
    assertEq(vault.borrowableAssets(), 40_000e18, 'borrowable should be 40k');
    vm.prank(borrower);
    vault.borrow(40_000e18);
    assertEq(asset.balanceOf(borrower), 40_000e18);
  }

  function test_borrow_BorrowAmountTooHigh() external {
    vm.prank(alice);
    vault.depositUpTo(50_000e18);

    vm.startPrank(borrower);
    vm.expectRevert(IVaultEventsAndErrors.BorrowAmountTooHigh.selector);
    vault.borrow(40_000e18 + 1);
  }

  // ===================================================================== //
  //                             closeVault()                              //
  // ===================================================================== //

  function test_closeVault_TransferRemainingDebt() external asAccount(address(controller)) {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    startPrank(borrower);
    asset.approve(address(vault), 8e17);
    stopPrank();
    vm.expectEmit(address(asset));
    emit Transfer(borrower, address(vault), 8e17);
    vault.closeVault();
  }

  function test_closeVault_TransferExcessAssets() external asAccount(address(controller)) {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    asset.mint(address(vault), 1e18);
    vm.expectEmit(address(asset));
    emit Transfer(address(vault), borrower, 2e17);
    vault.closeVault();
  }

  function test_closeVault_FailTransferRemainingDebt() external asAccount(address(controller)) {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
    vault.closeVault();
  }

  function test_closeVault_NotController() external {
    vm.expectRevert(IVaultEventsAndErrors.NotController.selector);
    vault.closeVault();
  }

  function test_closeVault_CloseVaultWithUnpaidWithdrawals()
    external
    asAccount(address(controller))
  {
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    fastForward(parameters.withdrawalBatchDuration);
    vault.updateState();
    uint32[] memory unpaidBatches = vault.getUnpaidBatchExpiries();
    assertEq(unpaidBatches.length, 1);
    vm.expectRevert(IVaultEventsAndErrors.CloseVaultWithUnpaidWithdrawals.selector);
    vault.closeVault();
  }
}
