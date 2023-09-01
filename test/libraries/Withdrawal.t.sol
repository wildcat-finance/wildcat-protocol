// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'forge-std/Test.sol';
import 'src/libraries/Withdrawal.sol';

contract WithdrawalTest is Test {
	WithdrawalData internal _withdrawalData;

	event WithdrawalBatchCreated(uint256 expiry);
	event WithdrawalQueued(uint256 expiry, address account, uint256 scaledAmount);

	function test_availableLiquidityForPendingBatch(
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
		assertEq(WithdrawalLib.availableLiquidityForPendingBatch(batch, state, totalAssets), expected);
	}
}
