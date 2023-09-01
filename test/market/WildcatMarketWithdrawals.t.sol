// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../BaseVaultTest.sol';

contract WithdrawalsTest is BaseVaultTest {
	using MathUtils for uint256;
	using FeeMath for uint256;

	function test_queueWithdrawal_NotApprovedLender() external {
		_deposit(alice, 1e18);
		vm.prank(alice);
		vault.transfer(bob, 1e18);
		vm.startPrank(bob);
		vm.expectRevert(IVaultEventsAndErrors.NotApprovedLender.selector);
		vault.queueWithdrawal(1e18);
	}

	function test_queueWithdrawal_NullBurnAmount() external asAccount(alice) {
		vm.expectRevert(IVaultEventsAndErrors.NullBurnAmount.selector);
		vault.queueWithdrawal(0);
	}

	function test_queueWithdrawal_InsufficientBalance() external asAccount(alice) {
		_deposit(alice, 1e18);
		vm.expectRevert(abi.encodePacked(uint32(Panic_ErrorSelector), Panic_Arithmetic));
		vault.queueWithdrawal(1e18 + 1);
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
		VaultState memory state = previousState;
		assertEq(state.isDelinquent, false, 'isDelinquent');
		assertEq(state.timeDelinquent, 0, 'timeDelinquent');
		assertEq(state.scaledPendingWithdrawals, 0, 'scaledPendingWithdrawals');
		assertEq(state.scaledTotalSupply, 0, 'scaledTotalSupply');
		assertEq(state.reservedAssets, userBalance1 + userBalance2, 'reservedAssets');
	}

	function test_queueWithdrawal_BurnAll(
		uint128 userBalance,
		uint128 withdrawalAmount
	) external asAccount(alice) {
		userBalance = uint128(bound(userBalance, 2, DefaultMaximumSupply));
		_deposit(alice, userBalance);
		_requestWithdrawal(alice, userBalance);
		VaultState memory state = previousState;
		assertEq(state.isDelinquent, false, 'isDelinquent');
		assertEq(state.timeDelinquent, 0, 'timeDelinquent');
		assertEq(state.scaledPendingWithdrawals, 0, 'scaledPendingWithdrawals');
		assertEq(state.scaledTotalSupply, 0, 'scaledTotalSupply');
		assertEq(state.reservedAssets, userBalance, 'reservedAssets');
	}

	function test_queueWithdrawal_BurnPartial(
		uint128 userBalance,
		uint128 borrowAmount
	) external asAccount(alice) {
		userBalance = uint128(bound(userBalance, 2, DefaultMaximumSupply));
		borrowAmount = uint128(
			bound(borrowAmount, 2, uint256(userBalance).bipMul(10000 - parameters.liquidityCoverageRatio))
		);
		_deposit(alice, userBalance);
		_borrow(borrowAmount);
		_requestWithdrawal(alice, userBalance);
		VaultState memory state = previousState;
		assertEq(state.isDelinquent, true, 'state.isDelinquent');
		assertEq(state.timeDelinquent, 0, 'state.timeDelinquent');
		uint128 remainingAssets = userBalance - borrowAmount;

		assertEq(state.scaledPendingWithdrawals, borrowAmount, 'state.scaledPendingWithdrawals');
		assertEq(state.scaledTotalSupply, borrowAmount, 'state.scaledTotalSupply');
		assertEq(state.reservedAssets, remainingAssets, 'state.reservedAssets');
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
		vm.expectRevert(IVaultEventsAndErrors.WithdrawalBatchNotExpired.selector);
		vault.executeWithdrawal(alice, uint32(block.timestamp + parameters.withdrawalBatchDuration));
	}

	function test_executeWithdrawal(uint128 userBalance, uint128 withdrawalAmount) external {
		userBalance = uint128(bound(userBalance, 2, DefaultMaximumSupply));
		withdrawalAmount = uint128(bound(withdrawalAmount, 2, userBalance));
		_deposit(alice, userBalance);
		_requestWithdrawal(alice, withdrawalAmount);
		uint256 expiry = block.timestamp + parameters.withdrawalBatchDuration;
		fastForward(parameters.withdrawalBatchDuration);
		VaultState memory state = pendingState();
		updateState(state);
		uint256 previousBalance = asset.balanceOf(alice);
		uint256 withdrawalAmount = state.reservedAssets;
		vm.prank(alice);
		vault.executeWithdrawal(alice, uint32(expiry));
		assertEq(asset.balanceOf(alice), previousBalance + withdrawalAmount);
	}

  

	function test_processUnpaidWithdrawalBatch_NoUnpaidBatches() external {
		vm.expectRevert(FIFOQueueLib.FIFOQueueOutOfBounds.selector);
		vault.processUnpaidWithdrawalBatch();
	}

	function _checkBatch(
		uint32 expiry,
		uint256 scaledTotalAmount,
		uint256 scaledAmountBurned,
		uint256 normalizedAmountPaid
	) internal {
		WithdrawalBatch memory batch = vault.getWithdrawalBatch(expiry);
		assertEq(batch.scaledTotalAmount, scaledTotalAmount, 'scaledAmountBurned');
		assertEq(batch.scaledAmountBurned, scaledAmountBurned, 'scaledAmountBurned');
		assertEq(batch.normalizedAmountPaid, normalizedAmountPaid, 'normalizedAmountPaid');
	}

	function test_processUnpaidWithdrawalBatch() external {
		_deposit(alice, 1e18);
		// Borrow 80% of vault assets
		_borrow(8e17);
		// Withdraw 100% of deposits
		_requestWithdrawal(alice, 1e18);
		assertEq(vault.previousState().isDelinquent, true);
		fastForward(parameters.withdrawalBatchDuration);
		uint32 expiry = uint32(block.timestamp);
		_checkBatch(expiry, 1e18, 2e17, 2e17);
		updateState(pendingState());
		vault.updateState();
		uint32[] memory unpaidBatchExpiries = vault.getUnpaidBatchExpiries();
		assertEq(unpaidBatchExpiries.length, 1);
		assertEq(unpaidBatchExpiries[0], expiry);
		_checkState();
		assertEq(vault.previousState().timeDelinquent, parameters.withdrawalBatchDuration);

		VaultState memory state = pendingState();
		_checkBatch(expiry, 1e18, 2e17, 2e17);
		assertEq(state.accruedProtocolFees, uint256(8e15) / 365);

		asset.mint(address(vault), 8e17 + state.accruedProtocolFees);
		vault.processUnpaidWithdrawalBatch();
		uint256 delinquencyFeeRay = FeeMath.calculateLinearInterestFromBips(
			parameters.delinquencyFeeBips,
			uint256(parameters.withdrawalBatchDuration).satSub(parameters.delinquencyGracePeriod)
		);
		uint256 baseInterestRay = FeeMath.calculateLinearInterestFromBips(
			parameters.annualInterestBips,
			parameters.withdrawalBatchDuration
		);
		uint256 feesAccruedOnWithdrawal = (delinquencyFeeRay + baseInterestRay).rayMul(8e17);
		asset.mint(address(vault), feesAccruedOnWithdrawal);
		vault.processUnpaidWithdrawalBatch();
		_checkBatch(expiry, 1e18, 1e18, 1e18 + feesAccruedOnWithdrawal);
		assertEq(vault.getUnpaidBatchExpiries().length, 0);
	}
}
