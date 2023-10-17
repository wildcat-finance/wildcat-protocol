// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../BaseMarketTest.sol';

contract WithdrawalsTest is BaseMarketTest {
  using MathUtils for uint256;
  using FeeMath for uint256;

  function test_queueWithdrawal_NotApprovedLender() external {
    _deposit(alice, 1e18);
    vm.prank(alice);
    market.transfer(bob, 1e18);
    vm.startPrank(bob);
    vm.expectRevert(IMarketEventsAndErrors.NotApprovedLender.selector);
    market.queueWithdrawal(1e18);
  }

  function test_queueWithdrawal_AuthorizedWithdrawOnly() public asAccount(bob) {
    _deposit(bob, 1e18);
    startPrank(address(controller));
    market.updateAccountAuthorization(bob, false);
    stopPrank();
    _requestWithdrawal(bob, 1e18);
  }

  function test_queueWithdrawal_AuthorizedOnController() public {
    _deposit(alice, 1e18);
    vm.prank(alice);
    market.transfer(bob, 1e18);
    _authorizeLender(bob);
    vm.startPrank(bob);
    market.queueWithdrawal(1e18);
  }

  function test_queueWithdrawal_NullBurnAmount() external asAccount(alice) {
    vm.expectRevert(IMarketEventsAndErrors.NullBurnAmount.selector);
    market.queueWithdrawal(0);
  }

  function test_queueWithdrawal_InsufficientBalance() external asAccount(alice) {
    _deposit(alice, 1e18);
    vm.expectRevert(abi.encodePacked(uint32(Panic_ErrorSelector), Panic_Arithmetic));
    market.queueWithdrawal(1e18 + 1);
  }

  function test_queueWithdrawal_AddToExisting(
    uint256 userBalance1,
    uint256 withdrawalAmount1,
    uint256 userBalance2,
    uint256 withdrawalAmount2
  ) external asAccount(alice) {
    (userBalance1, withdrawalAmount1) = dbound(
      userBalance1,
      withdrawalAmount1,
      2,
      DefaultMaximumSupply / 2
    );
    (userBalance2, withdrawalAmount2) = dbound(
      userBalance2,
      withdrawalAmount2,
      2,
      DefaultMaximumSupply - userBalance1
    );
    _deposit(alice, userBalance1);
    _deposit(bob, userBalance2);
    _requestWithdrawal(alice, userBalance1);
    _requestWithdrawal(bob, userBalance2);
    MarketState memory state = previousState;
    assertEq(state.isDelinquent, false, 'isDelinquent');
    assertEq(state.timeDelinquent, 0, 'timeDelinquent');
    assertEq(state.scaledPendingWithdrawals, 0, 'scaledPendingWithdrawals');
    assertEq(state.scaledTotalSupply, 0, 'scaledTotalSupply');
    assertEq(
      state.normalizedUnclaimedWithdrawals,
      userBalance1 + userBalance2,
      'normalizedUnclaimedWithdrawals'
    );
  }

  function test_queueWithdrawal_BurnAll(
    uint128 userBalance,
    uint128 withdrawalAmount
  ) external asAccount(alice) {
    userBalance = uint128(bound(userBalance, 2, DefaultMaximumSupply));
    _deposit(alice, userBalance);
    _requestWithdrawal(alice, userBalance);
    MarketState memory state = previousState;
    assertEq(state.isDelinquent, false, 'isDelinquent');
    assertEq(state.timeDelinquent, 0, 'timeDelinquent');
    assertEq(state.scaledPendingWithdrawals, 0, 'scaledPendingWithdrawals');
    assertEq(state.scaledTotalSupply, 0, 'scaledTotalSupply');
    assertEq(state.normalizedUnclaimedWithdrawals, userBalance, 'normalizedUnclaimedWithdrawals');
  }

  function test_queueWithdrawal_BurnPartial(
    uint128 userBalance,
    uint128 borrowAmount
  ) external asAccount(alice) {
    userBalance = uint128(bound(userBalance, 2, DefaultMaximumSupply));
    borrowAmount = uint128(
      bound(borrowAmount, 2, uint256(userBalance).bipMul(10000 - parameters.reserveRatioBips))
    );
    _deposit(alice, userBalance);
    _borrow(borrowAmount);
    _requestWithdrawal(alice, userBalance);
    MarketState memory state = previousState;
    assertEq(state.isDelinquent, true, 'state.isDelinquent');
    assertEq(state.timeDelinquent, 0, 'state.timeDelinquent');
    uint128 remainingAssets = userBalance - borrowAmount;

    assertEq(state.scaledPendingWithdrawals, borrowAmount, 'state.scaledPendingWithdrawals');
    assertEq(state.scaledTotalSupply, borrowAmount, 'state.scaledTotalSupply');
    assertEq(
      state.normalizedUnclaimedWithdrawals,
      remainingAssets,
      'state.normalizedUnclaimedWithdrawals'
    );
  }

  function test_queueWithdrawal(
    uint128 userBalance,
    uint128 withdrawalAmount
  ) external asAccount(alice) {
    userBalance = uint128(bound(userBalance, 2, DefaultMaximumSupply));
    withdrawalAmount = uint128(bound(withdrawalAmount, 2, userBalance));
    _deposit(alice, userBalance);
    _requestWithdrawal(alice, withdrawalAmount);
  }

  function test_executeWithdrawal_NotExpired(
    uint128 userBalance,
    uint128 withdrawalAmount
  ) external {
    userBalance = uint128(bound(userBalance, 2, DefaultMaximumSupply));
    withdrawalAmount = uint128(bound(withdrawalAmount, 2, userBalance));
    _deposit(alice, userBalance);
    _requestWithdrawal(alice, withdrawalAmount);
    vm.expectRevert(IMarketEventsAndErrors.WithdrawalBatchNotExpired.selector);
    market.executeWithdrawal(alice, uint32(block.timestamp + parameters.withdrawalBatchDuration));
  }

  function test_executeWithdrawal(uint128 userBalance, uint128 withdrawalAmount) external {
    userBalance = uint128(bound(userBalance, 2, DefaultMaximumSupply));
    withdrawalAmount = uint128(bound(withdrawalAmount, 2, userBalance));
    _deposit(alice, userBalance);
    _requestWithdrawal(alice, withdrawalAmount);
    uint256 expiry = block.timestamp + parameters.withdrawalBatchDuration;
    fastForward(parameters.withdrawalBatchDuration);
    MarketState memory state = pendingState();
    updateState(state);
    uint256 previousBalance = asset.balanceOf(alice);
    uint256 withdrawalAmount = state.normalizedUnclaimedWithdrawals;
    vm.prank(alice);
    market.executeWithdrawal(alice, uint32(expiry));
    assertEq(asset.balanceOf(alice), previousBalance + withdrawalAmount);
  }

  function test_executeWithdrawal_NullWithdrawalAmount(
    uint128 userBalance,
    uint128 withdrawalAmount
  ) external {
    userBalance = uint128(bound(userBalance, 2, DefaultMaximumSupply));
    withdrawalAmount = uint128(bound(withdrawalAmount, 2, userBalance));
    _deposit(alice, userBalance);
    _requestWithdrawal(alice, withdrawalAmount);
    uint256 expiry = block.timestamp + parameters.withdrawalBatchDuration;
    fastForward(parameters.withdrawalBatchDuration);
    MarketState memory state = pendingState();
    updateState(state);
    uint256 previousBalance = asset.balanceOf(alice);
    uint256 withdrawalAmount = state.normalizedUnclaimedWithdrawals;
    vm.prank(alice);
    market.executeWithdrawal(alice, uint32(expiry));
    assertEq(asset.balanceOf(alice), previousBalance + withdrawalAmount);
    vm.expectRevert(IMarketEventsAndErrors.NullWithdrawalAmount.selector);
    market.executeWithdrawal(alice, uint32(expiry));
  }

  function test_executeWithdrawal_Sanctioned() external {
    _deposit(alice, 1e18);
    _requestWithdrawal(alice, 1e18);
    fastForward(parameters.withdrawalBatchDuration);
    sanctionsSentinel.sanction(alice);
    address escrow = sanctionsSentinel.getEscrowAddress(alice, borrower, address(asset));
    vm.expectEmit(address(asset));
    emit Transfer(address(market), escrow, 1e18);
    vm.expectEmit(address(market));
    emit SanctionedAccountWithdrawalSentToEscrow(alice, escrow, uint32(block.timestamp), 1e18);
    market.executeWithdrawal(alice, uint32(block.timestamp));
  }

  function test_processUnpaidWithdrawalBatch_NoUnpaidBatches() external {
    vm.expectRevert(FIFOQueueLib.FIFOQueueOutOfBounds.selector);
    market.processUnpaidWithdrawalBatch();
  }

  function _checkBatch(
    uint32 expiry,
    uint256 scaledTotalAmount,
    uint256 scaledAmountBurned,
    uint256 normalizedAmountPaid
  ) internal {
    WithdrawalBatch memory batch = market.getWithdrawalBatch(expiry);
    assertEq(batch.scaledTotalAmount, scaledTotalAmount, 'scaledAmountBurned');
    assertEq(batch.scaledAmountBurned, scaledAmountBurned, 'scaledAmountBurned');
    assertEq(batch.normalizedAmountPaid, normalizedAmountPaid, 'normalizedAmountPaid');
  }

  function test_processUnpaidWithdrawalBatch() external {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    assertEq(market.previousState().isDelinquent, true);
    fastForward(parameters.withdrawalBatchDuration);
    uint32 expiry = uint32(block.timestamp);
    _checkBatch(expiry, 1e18, 2e17, 2e17);
    updateState(pendingState());
    market.updateState();
    uint32[] memory unpaidBatchExpiries = market.getUnpaidBatchExpiries();
    assertEq(unpaidBatchExpiries.length, 1);
    assertEq(unpaidBatchExpiries[0], expiry);
    _checkState();
    assertEq(market.previousState().timeDelinquent, parameters.withdrawalBatchDuration);

    MarketState memory state = pendingState();
    _checkBatch(expiry, 1e18, 2e17, 2e17);
    assertEq(state.accruedProtocolFees, uint256(8e15) / 365);

    asset.mint(address(market), 8e17 + state.accruedProtocolFees);
    market.processUnpaidWithdrawalBatch();
    uint256 delinquencyFeeRay = FeeMath.calculateLinearInterestFromBips(
      parameters.delinquencyFeeBips,
      uint256(parameters.withdrawalBatchDuration).satSub(parameters.delinquencyGracePeriod)
    );
    uint256 baseInterestRay = FeeMath.calculateLinearInterestFromBips(
      parameters.annualInterestBips,
      parameters.withdrawalBatchDuration
    );
    uint256 feesAccruedOnWithdrawal = (delinquencyFeeRay + baseInterestRay).rayMul(8e17);
    asset.mint(address(market), feesAccruedOnWithdrawal);
    market.processUnpaidWithdrawalBatch();
    _checkBatch(expiry, 1e18, 1e18, 1e18 + feesAccruedOnWithdrawal);
    assertEq(market.getUnpaidBatchExpiries().length, 0);
  }

  function test_getWithdrawalBatch_DoesNotExist() external {
    WithdrawalBatch memory batch = market.getWithdrawalBatch(0);
    assertEq(batch.scaledTotalAmount, 0);
    assertEq(batch.scaledAmountBurned, 0);
    assertEq(batch.normalizedAmountPaid, 0);
  }

  function test_getWithdrawalBatch_Expired() external {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 3e17);
    assertEq(market.previousState().isDelinquent, true);
    fastForward(parameters.withdrawalBatchDuration);
    uint32 expiry = uint32(block.timestamp);
    _checkBatch(expiry, 3e17, 2e17, 2e17);
    assertEq(market.previousState().pendingWithdrawalExpiry, expiry);
    updateState(pendingState());
    _requestWithdrawal(alice, 7e17);
    fastForward(parameters.withdrawalBatchDuration);
    updateState(pendingState());
    _checkBatch(0, 0, 0, 0);
  }

  function test_getWithdrawalBatch_Paid() external {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _deposit(alice, 2e18);
    _requestWithdrawal(alice, 1e18);
    fastForward(parameters.withdrawalBatchDuration);
    uint32 expiry = uint32(block.timestamp);
    _checkBatch(expiry, 1e18, 1e18, 1e18);
    updateState(pendingState());
  }

  function test_getAccountWithdrawalStatus() external {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    uint32 expiry = uint32(block.timestamp + parameters.withdrawalBatchDuration);
    AccountWithdrawalStatus memory status = market.getAccountWithdrawalStatus(alice, expiry);
    assertEq(status.scaledAmount, 1e18);
    assertEq(status.normalizedAmountWithdrawn, 0);
    fastForward(parameters.withdrawalBatchDuration);
    market.updateState();
    market.executeWithdrawal(alice, expiry);
    status = market.getAccountWithdrawalStatus(alice, expiry);
    assertEq(status.scaledAmount, 1e18);
    assertEq(status.normalizedAmountWithdrawn, 2e17);
  }

  function test_getAvailableWithdrawalAmount() external {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    uint32 expiry = uint32(block.timestamp + parameters.withdrawalBatchDuration);
    fastForward(parameters.withdrawalBatchDuration);
    AccountWithdrawalStatus memory status = market.getAccountWithdrawalStatus(alice, expiry);
    uint256 withdrawableAmount = market.getAvailableWithdrawalAmount(alice, expiry);
    assertEq(withdrawableAmount, 2e17);
  }

  function test_getAvailableWithdrawalAmount_UnpaidBatch() external {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    uint32 expiry = uint32(block.timestamp + parameters.withdrawalBatchDuration);
    fastForward(parameters.withdrawalBatchDuration);
    market.updateState();
    AccountWithdrawalStatus memory status = market.getAccountWithdrawalStatus(alice, expiry);
    uint256 withdrawableAmount = market.getAvailableWithdrawalAmount(alice, expiry);
    assertEq(withdrawableAmount, 2e17);
  }

  function test_getAvailableWithdrawalAmount_NotExpired() external {
    vm.expectRevert(IMarketEventsAndErrors.WithdrawalBatchNotExpired.selector);
    market.getAvailableWithdrawalAmount(alice, uint32(block.timestamp + 1));
  }

  function test_getAvailableWithdrawalAmount_AtExpiry() external {
    // Borrow 80% of deposits then request withdrawal of 100% of deposits
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    uint32 expiry = uint32(block.timestamp + parameters.withdrawalBatchDuration);
    fastForward(parameters.withdrawalBatchDuration);
    AccountWithdrawalStatus memory status = market.getAccountWithdrawalStatus(alice, expiry);
    uint256 withdrawableAmount = market.getAvailableWithdrawalAmount(alice, expiry);
    assertEq(withdrawableAmount, 2e17);
  }
}
