// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'forge-std/Test.sol';
import 'src/libraries/Withdrawal.sol';

contract WithdrawalTest is Test {
	WithdrawalData internal _withdrawalData;

	event WithdrawalBatchCreated(uint256 expiry);
	event WithdrawalQueued(uint256 expiry, address account, uint256 scaledAmount);

	function _addWithdrawalRequest(
		VaultState memory state,
		address account,
		uint104 scaledAmount,
		uint256 withdrawalBatchDuration
	) external returns (VaultState memory) {
		WithdrawalLib.addWithdrawalRequest(
			_withdrawalData,
			state,
			account,
			scaledAmount,
			withdrawalBatchDuration
		);
		return state;
	}

	function test_addWithdrawalRequest(
		uint32 pendingWithdrawalExpiry,
		address account,
		uint104 scaledAmount,
		// uint104 scaledTotalPendingWithdrawals,
		uint32 withdrawalBatchDuration
	) external {
		withdrawalBatchDuration = uint32(
			bound(withdrawalBatchDuration, 1, type(uint32).max - block.timestamp)
		);
		VaultState memory state;
		pendingWithdrawalExpiry = uint32(bound(pendingWithdrawalExpiry, 0, uint32(block.timestamp)));
		state.pendingWithdrawalExpiry = pendingWithdrawalExpiry;
		if (pendingWithdrawalExpiry == 0) {
			vm.expectEmit();
			emit WithdrawalBatchCreated(block.timestamp + withdrawalBatchDuration);
		}
		uint32 newExpiry = uint32(
			pendingWithdrawalExpiry == 0
				? block.timestamp + withdrawalBatchDuration
				: pendingWithdrawalExpiry
		);
		vm.expectEmit();
		emit WithdrawalQueued(uint256(newExpiry), address(account), uint256(scaledAmount));
		state = this._addWithdrawalRequest(state, account, scaledAmount, withdrawalBatchDuration);
		assertEq(_withdrawalData.accountStatuses[newExpiry][account].scaledAmount, scaledAmount);
		assertEq(_withdrawalData.batches[newExpiry].scaledTotalAmount, scaledAmount);
		assertEq(state.scaledPendingWithdrawals, scaledAmount);

		assertEq(state.pendingWithdrawalExpiry, newExpiry);
	}

	function test_withdrawAvailable(
		address account,
		uint256 expiry,
		uint256 scaledWithdrawalAmount,
		uint256 scaledTotalBatchAmount,
		uint256 previousNormalizedAmountWithdrawn,
		uint256 normalizedAmountPaid,
		uint256 reservedAssets
	) external {
		expiry = bound(expiry, 0, type(uint32).max);
		scaledTotalBatchAmount = bound(scaledTotalBatchAmount, 1, type(uint104).max);
		scaledWithdrawalAmount = bound(scaledWithdrawalAmount, 1, scaledTotalBatchAmount);
		reservedAssets = bound(reservedAssets, 1, type(uint128).max);
		normalizedAmountPaid = bound(normalizedAmountPaid, 1, reservedAssets);
		uint256 newTotal = (normalizedAmountPaid * scaledWithdrawalAmount) / scaledTotalBatchAmount;
		previousNormalizedAmountWithdrawn = bound(previousNormalizedAmountWithdrawn, 0, newTotal);

		_withdrawalData.batches[uint32(expiry)].scaledTotalAmount = uint104(scaledTotalBatchAmount);
		_withdrawalData.batches[uint32(expiry)].normalizedAmountPaid = uint128(normalizedAmountPaid);
		_withdrawalData.accountStatuses[expiry][account].scaledAmount = uint104(scaledWithdrawalAmount);
		_withdrawalData.accountStatuses[expiry][account].normalizedAmountWithdrawn = uint128(
			previousNormalizedAmountWithdrawn
		);
		VaultState memory state;
		state.reservedAssets = uint128(reservedAssets);
		uint256 expectedOutput = newTotal - previousNormalizedAmountWithdrawn;
		assertEq(
			WithdrawalLib.withdrawAvailable(_withdrawalData, state, account, uint32(expiry)),
			expectedOutput
		);
		assertEq(state.reservedAssets, reservedAssets - expectedOutput);
		assertEq(
			_withdrawalData.accountStatuses[expiry][account].normalizedAmountWithdrawn,
			previousNormalizedAmountWithdrawn + expectedOutput
		);
	}

	function test_availableLiquidityForBatch(
		uint128 totalAssets,
		uint104 scaledTotalPendingWithdrawals,
		uint104 scaledBatchAmount,
		uint128 reservedAssets,
		uint96 scaleFactor,
		uint128 accruedProtocolFees
	) external {
		scaledTotalPendingWithdrawals = uint104(
			bound(scaledTotalPendingWithdrawals, 1, type(uint104).max)
		);
		scaledBatchAmount = uint104(bound(scaledBatchAmount, 1, scaledTotalPendingWithdrawals));
		VaultState memory state;
		state.reservedAssets = reservedAssets;
		state.accruedProtocolFees = accruedProtocolFees;
		state.scaleFactor = scaleFactor;
		state.scaledPendingWithdrawals = scaledTotalPendingWithdrawals;
		WithdrawalBatch memory batch;
		batch.scaledTotalAmount = scaledBatchAmount;
		uint256 totalReserved = uint256(reservedAssets) +
			uint256(accruedProtocolFees) +
			state.normalizeAmount(scaledTotalPendingWithdrawals - scaledBatchAmount);
		uint256 expected = totalAssets > totalReserved ? totalAssets - totalReserved : 0;
		assertEq(WithdrawalLib.availableLiquidityForBatch(batch, state, totalAssets), expected);
	}
}
