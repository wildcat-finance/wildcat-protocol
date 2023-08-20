// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'forge-std/Test.sol';
import 'src/libraries/Withdrawal.sol';
import 'src/libraries/MathUtils.sol';

using MathUtils for uint256;

contract VaultStateTest is Test {
	WithdrawalData internal _withdrawalData;

	function test_scaleAmount(uint128 normalizedAmount) external returns (uint256) {
		VaultState memory state;
		state.scaleFactor = uint112(RAY);

		assertEq(state.scaleAmount(normalizedAmount), normalizedAmount);
	}

	function test_scaleAmount(
		uint112 scaleFactor,
		uint128 normalizedAmount
	) external returns (uint256) {
		scaleFactor = uint112(bound(scaleFactor, RAY, type(uint112).max));
		VaultState memory state;
		state.scaleFactor = scaleFactor;
		assertEq(state.scaleAmount(normalizedAmount), uint256(normalizedAmount).rayDiv(scaleFactor));
	}

	function test_normalizeAmount(uint104 scaledAmount) external {
		VaultState memory state;
		state.scaleFactor = uint112(RAY);

		assertEq(state.normalizeAmount(scaledAmount), scaledAmount);
	}

	function test_normalizeAmount(
		uint112 scaleFactor,
		uint104 scaledAmount
	) external returns (uint256) {
		scaleFactor = uint112(bound(scaleFactor, RAY, type(uint112).max));
		VaultState memory state;
		state.scaleFactor = scaleFactor;

		assertEq(state.normalizeAmount(scaledAmount), uint256(scaledAmount).rayMul(scaleFactor));
	}

	function test_totalSupply(
		uint112 scaleFactor,
		uint104 scaledTotalSupply
	) external returns (uint256) {
		scaleFactor = uint112(bound(scaleFactor, RAY, type(uint112).max));
		VaultState memory state;
		state.scaleFactor = scaleFactor;
		state.scaledTotalSupply = scaledTotalSupply;

		assertEq(state.totalSupply(), state.normalizeAmount(scaledTotalSupply));
	}

	function test_maximumDeposit() external returns (uint256) {
		VaultState memory state;
		uint256 expected;
		assertEq(expected, state.maximumDeposit());
	}

	function test_liquidityRequired(
		uint104 scaledPendingWithdrawals,
		uint104 scaledTotalSupply,
		uint16 liquidityCoverageRatio,
		uint128 accruedProtocolFees,
		uint128 reservedAssets
	) external returns (uint256 _liquidityRequired) {
		liquidityCoverageRatio = uint16(bound(liquidityCoverageRatio, 1, 10000));
		scaledPendingWithdrawals = uint104(bound(scaledPendingWithdrawals, 0, scaledTotalSupply));

		VaultState memory state;
		state.scaledPendingWithdrawals = scaledPendingWithdrawals;
		state.scaledTotalSupply = scaledTotalSupply;
		state.liquidityCoverageRatio = liquidityCoverageRatio;
		state.accruedProtocolFees = accruedProtocolFees;
		state.reservedAssets = reservedAssets;

		uint256 collateralForOutstanding = (uint256(scaledTotalSupply - scaledPendingWithdrawals) *
			uint256(liquidityCoverageRatio)) / uint256(10000);

		assertEq(
			state.liquidityRequired(),
			collateralForOutstanding + uint256(scaledPendingWithdrawals) + uint256(accruedProtocolFees)
		);
	}

	function test_liquidAssets(uint256 totalAssets) external returns (uint256) {
		VaultState memory state;
		uint256 expected;
		assertEq(expected, state.liquidAssets(totalAssets));
	}

	function test_hasPendingBatch(uint32 pendingWithdrawalExpiry) external returns (bool) {
		VaultState memory state;
		state.pendingWithdrawalExpiry = pendingWithdrawalExpiry;

		assertEq(state.hasPendingBatch(), pendingWithdrawalExpiry != 0);
	}

	function test_hasPendingExpiredBatch(
		uint32 pendingWithdrawalExpiry
	) external returns (bool result) {
		VaultState memory state;
		state.pendingWithdrawalExpiry = pendingWithdrawalExpiry;

		assertEq(
			state.hasPendingExpiredBatch(),
			pendingWithdrawalExpiry > 0 && pendingWithdrawalExpiry <= block.timestamp
		);
	}

	function test_decreaseScaledTotalSupply(
		uint104 scaledTotalSupply,
		uint104 scaledAmount
	) external {
		scaledAmount = uint104(bound(scaledAmount, 0, scaledTotalSupply));
		VaultState memory state;
		state.scaledTotalSupply = scaledTotalSupply;
		state.decreaseScaledTotalSupply(scaledAmount);
		assertEq(state.scaledTotalSupply, scaledTotalSupply - scaledAmount);
	}

	function test_increaseScaledTotalSupply(
		uint104 scaledTotalSupply,
		uint104 scaledAmount
	) external {
		scaledAmount = uint104(bound(scaledAmount, 0, type(uint104).max - scaledTotalSupply));
		VaultState memory state;
		state.scaledTotalSupply = scaledTotalSupply;
		state.increaseScaledTotalSupply(scaledAmount);
		assertEq(state.scaledTotalSupply, scaledTotalSupply + scaledAmount);
	}
	/* 
	function test_decreaseScaledBalance(uint104 scaledAmount) external  {
		Account memory account;
		uint256 expected;
		assertEq(expected, account.decreaseScaledBalance(scaledAmount));
	}

	function test_increaseScaledBalance(uint104 scaledAmount) external  {
		Account memory account;
		uint256 expected;
		assertEq(expected, account.increaseScaledBalance(scaledAmount));
	}
} */
}
