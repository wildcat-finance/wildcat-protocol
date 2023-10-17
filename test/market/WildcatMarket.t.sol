// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../BaseMarketTest.sol';
import 'src/interfaces/IMarketEventsAndErrors.sol';
import 'src/libraries/MathUtils.sol';
import 'src/libraries/SafeCastLib.sol';
import 'src/libraries/MarketState.sol';
import 'solady/utils/SafeTransferLib.sol';

contract WildcatMarketTest is BaseMarketTest {
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
    MarketState memory state = pendingState();
    updateState(state);
    market.updateState();
    assertEq(market.previousState(), state);
  }

  function test_updateState_NoChange() external {
    _deposit(alice, 1e18);
    MarketState memory state = pendingState();
    bytes32 stateHash = keccak256(abi.encode(state));
    market.updateState();
    assertEq(keccak256(abi.encode(market.previousState())), stateHash);
    assertEq(keccak256(abi.encode(market.currentState())), stateHash);
  }

  function test_updateState_HasPendingExpiredBatch() external {
    parameters.annualInterestBips = 3650;
    setUp();
    _deposit(alice, 1e18);
    _requestWithdrawal(alice, 1e18);
    uint32 expiry = previousState.pendingWithdrawalExpiry;
    fastForward(1 days);
    MarketState memory state = pendingState();
    vm.expectEmit(address(market));
    emit ScaleFactorUpdated(1.001e27, 1e24, 0, 0);
    vm.expectEmit(address(market));
    emit WithdrawalBatchExpired(expiry, 1e18, 1e18, 1e18);
    vm.expectEmit(address(market));
    emit WithdrawalBatchClosed(expiry);
    vm.expectEmit(address(market));
    emit StateUpdated(1.001e27, false);
    market.updateState();
  }

  function test_updateState_HasPendingExpiredBatch_SameBlock() external {
    parameters.withdrawalBatchDuration = 0;
    setUpContracts(true);
    setUp();
    _deposit(alice, 1e18);
    _requestWithdrawal(alice, 1e18);
    MarketState memory state = pendingState();
    vm.expectEmit(address(market));
    emit WithdrawalBatchExpired(block.timestamp, 1e18, 1e18, 1e18);
    vm.expectEmit(address(market));
    emit WithdrawalBatchClosed(block.timestamp);
    vm.expectEmit(address(market));
    emit StateUpdated(1e27, false);
    market.updateState();
  }

  // ===================================================================== //
  //                         depositUpTo(uint256)                          //
  // ===================================================================== //

  function test_depositUpTo() external asAccount(alice) {
    _deposit(alice, 50_000e18);
    assertEq(market.totalSupply(), 50_000e18);
    assertEq(market.balanceOf(alice), 50_000e18);
  }

  function test_depositUpTo(uint256 amount) external asAccount(alice) {
    amount = bound(amount, 1, DefaultMaximumSupply);
    market.depositUpTo(amount);
  }

  function test_depositUpTo_ApprovedOnController() public asAccount(bob) {
    _authorizeLender(bob);
    vm.expectEmit(address(market));
    emit AuthorizationStatusUpdated(bob, AuthRole.DepositAndWithdraw);
    market.depositUpTo(1e18);
    assertEq(uint(market.getAccountRole(bob)), uint(AuthRole.DepositAndWithdraw));
  }

  function test_depositUpTo_NullMintAmount() external asAccount(alice) {
    vm.expectRevert(IMarketEventsAndErrors.NullMintAmount.selector);
    market.depositUpTo(0);
  }

  function testDepositUpTo_MaxSupplyExceeded() public asAccount(bob) {
    _authorizeLender(bob);
    asset.transfer(address(1), type(uint128).max);
    asset.mint(bob, DefaultMaximumSupply);
    asset.approve(address(market), DefaultMaximumSupply);
    market.depositUpTo(DefaultMaximumSupply - 1);
    market.depositUpTo(2);
    assertEq(market.balanceOf(bob), DefaultMaximumSupply);
    assertEq(asset.balanceOf(bob), 0);
  }

  function testDepositUpTo_NotApprovedLender() public asAccount(bob) {
    asset.mint(bob, 1e18);
    asset.approve(address(market), 1e18);
    vm.expectRevert(IMarketEventsAndErrors.NotApprovedLender.selector);
    market.depositUpTo(1e18);
  }

  function testDepositUpTo_TransferFail() public asAccount(alice) {
    asset.approve(address(market), 0);
    vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
    market.depositUpTo(50_000e18);
  }

  // ===================================================================== //
  //                           deposit(uint256)                            //
  // ===================================================================== //

  function test_deposit(uint256 amount) external asAccount(alice) {
    amount = bound(amount, 1, DefaultMaximumSupply);
    market.deposit(amount);
  }

  function testDeposit_NotApprovedLender() public asAccount(bob) {
    vm.expectRevert(IMarketEventsAndErrors.NotApprovedLender.selector);
    market.deposit(1e18);
  }

  function testDeposit_MaxSupplyExceeded() public asAccount(alice) {
    market.deposit(DefaultMaximumSupply - 1);
    vm.expectRevert(IMarketEventsAndErrors.MaxSupplyExceeded.selector);
    market.deposit(2);
  }

  // ===================================================================== //
  //                             collectFees()                             //
  // ===================================================================== //

  function test_collectFees_NoFeesAccrued() external {
    vm.expectRevert(IMarketEventsAndErrors.NullFeeAmount.selector);
    market.collectFees();
  }

  function test_collectFees() external {
    _deposit(alice, 1e18);
    fastForward(365 days);
    vm.expectEmit(address(asset));
    emit Transfer(address(market), feeRecipient, 1e16);
    vm.expectEmit(address(market));
    emit FeesCollected(1e16);
    market.collectFees();
  }

  function test_collectFees_InsufficientReservesForFeeWithdrawal() external {
    _deposit(alice, 1e18);
    fastForward(1);
    asset.burn(address(market), 1e18);
    vm.expectRevert(IMarketEventsAndErrors.InsufficientReservesForFeeWithdrawal.selector);
    market.collectFees();
  }

  // ===================================================================== //
  //                            borrow(uint256)                            //
  // ===================================================================== //

  function test_borrow(uint256 amount) external {
    uint256 availableCollateral = market.borrowableAssets();
    assertEq(availableCollateral, 0, 'borrowable should be 0');

    vm.prank(alice);
    market.depositUpTo(50_000e18);
    assertEq(market.borrowableAssets(), 40_000e18, 'borrowable should be 40k');
    vm.prank(borrower);
    market.borrow(40_000e18);
    assertEq(asset.balanceOf(borrower), 40_000e18);
  }

  function test_borrow_BorrowAmountTooHigh() external {
    vm.prank(alice);
    market.depositUpTo(50_000e18);

    vm.startPrank(borrower);
    vm.expectRevert(IMarketEventsAndErrors.BorrowAmountTooHigh.selector);
    market.borrow(40_000e18 + 1);
  }

  // ===================================================================== //
  //                             closeMarket()                              //
  // ===================================================================== //

  function test_closeMarket_TransferRemainingDebt() external asAccount(address(controller)) {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    startPrank(borrower);
    asset.approve(address(market), 8e17);
    stopPrank();
    vm.expectEmit(address(asset));
    emit Transfer(borrower, address(market), 8e17);
    market.closeMarket();
  }

  function test_closeMarket_TransferExcessAssets() external asAccount(address(controller)) {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    asset.mint(address(market), 1e18);
    vm.expectEmit(address(asset));
    emit Transfer(address(market), borrower, 2e17);
    market.closeMarket();
  }

  function test_closeMarket_FailTransferRemainingDebt() external asAccount(address(controller)) {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
    market.closeMarket();
  }

  function test_closeMarket_NotController() external {
    vm.expectRevert(IMarketEventsAndErrors.NotController.selector);
    market.closeMarket();
  }

  function test_closeMarket_CloseMarketWithUnpaidWithdrawals()
    external
    asAccount(address(controller))
  {
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    fastForward(parameters.withdrawalBatchDuration);
    market.updateState();
    uint32[] memory unpaidBatches = market.getUnpaidBatchExpiries();
    assertEq(unpaidBatches.length, 1);
    vm.expectRevert(IMarketEventsAndErrors.CloseMarketWithUnpaidWithdrawals.selector);
    market.closeMarket();
  }
}
