// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { FeeMath, MathUtils, SafeCastLib, VaultState, WadRayMath } from 'reference/libraries/FeeMath.sol';
import 'forge-std/Test.sol';
import 'forge-std/console2.sol';
import 'forge-std/StdError.sol';
import '../shared/BaseTest.sol';

function maxRayMulRhs(uint256 left) pure returns (uint256 maxRight) {
	if (left == 0) return type(uint256).max;
	maxRight = (type(uint256).max - HALF_RAY) / left;
}

enum PenaltyFee {
	NONE,
	TEN_PCT,
	TWENTY_PCT
}

contract FeeMathTest is BaseTest {
	using MathUtils for uint256;
	using SafeCastLib for uint256;
	using WadRayMath for uint256;
	using FeeMath for VaultState;

	function testValidState(FuzzInput calldata inputs) external {
		VaultState memory state = getFuzzContext(inputs).state;
		uint256 vaultSupply = state.getTotalSupply();
		require(vaultSupply > 0);
	}

	// function testProtocolFees()

	function testCalculateInterestWithFees() external {
		VaultState memory state;
		state.timeDelinquent = 1000;
		state.isDelinquent = true;
		uint256 gracePeriod = 0;
		state.annualInterestBips = 1000;
		state.scaledTotalSupply = uint128(uint256(1e18).rayDiv(RAY));
		vm.warp(365 days);
		state.scaleFactor = uint112(RAY);
		(uint256 feesAccrued, bool didUpdate) = state.calculateInterestAndFees(
			1000,
			0,
			gracePeriod
		);
		assertEq(state.lastInterestAccruedTimestamp, block.timestamp);
		assertTrue(didUpdate, 'did not update');
		assertEq(feesAccrued, 1e16, 'incorrect feesAccrued');
		assertEq(state.scaleFactor, 1.09e27, 'incorrect scaleFactor');
	}

	function testCalculateInterestWithoutFeesWithPenalties() external {
		VaultState memory state;
		state.timeDelinquent = 1000;
		state.isDelinquent = true;
		uint256 gracePeriod = 0;
		state.annualInterestBips = 1000;
		state.scaledTotalSupply = uint128(uint256(1e18).rayDiv(RAY));
		vm.warp(365 days);
		state.scaleFactor = uint112(RAY);
		(uint256 feesAccrued, bool didUpdate) = state.calculateInterestAndFees(
			0,
			1000,
			gracePeriod
		);
		assertEq(state.lastInterestAccruedTimestamp, block.timestamp);
		assertTrue(didUpdate, 'did not update');
		assertEq(feesAccrued, 0, 'incorrect feesAccrued');
		assertEq(state.scaleFactor, 1.2e27, 'incorrect scaleFactor');
	}

	function testCalculateInterestWithFeesAndPenalties() external {
		VaultState memory state;
		state.timeDelinquent = 1000;
		state.isDelinquent = true;
		uint256 gracePeriod = 0;
		state.annualInterestBips = 1000;
		state.scaledTotalSupply = uint128(uint256(1e18).rayDiv(RAY));
		vm.warp(365 days);
		state.scaleFactor = uint112(RAY);
		(uint256 feesAccrued, bool didUpdate) = state.calculateInterestAndFees(
			1000,
			1000,
			gracePeriod
		);
		assertEq(state.lastInterestAccruedTimestamp, block.timestamp);
		assertTrue(didUpdate, 'did not update');
		assertEq(feesAccrued, 1e16, 'incorrect feesAccrued');
		assertEq(state.scaleFactor, 1.19e27, 'incorrect scaleFactor');
	}

	function testCalculateInterestWithoutFeesOrPenalties() external {
		VaultState memory state;
		state.timeDelinquent = 1000;
		state.isDelinquent = true;
		uint256 gracePeriod = 0;
		state.annualInterestBips = 1000;
		state.scaledTotalSupply = uint128(uint256(1e18).rayDiv(RAY));
		vm.warp(365 days);
		state.scaleFactor = uint112(RAY);
		(uint256 feesAccrued, bool didUpdate) = state.calculateInterestAndFees(
			0,
			0,
			gracePeriod
		);
		assertEq(state.lastInterestAccruedTimestamp, block.timestamp);
		assertTrue(didUpdate, 'did not update');
		assertEq(feesAccrued, 0, 'incorrect feesAccrued');
		assertEq(state.scaleFactor, 1.1e27, 'incorrect scaleFactor');
	}

	function testUpdateTimeDelinquentAndGetPenaltyTime() external {
		VaultState memory state;

		// Within grace period, no penalty
		state.timeDelinquent = 50;
		state.isDelinquent = true;
		assertEq(state.updateTimeDelinquentAndGetPenaltyTime(100, 25), 0);
		assertEq(state.timeDelinquent, 75);

		// Reach grace period cutoff, no penalty
		state.timeDelinquent = 50;
		state.isDelinquent = true;
		assertEq(state.updateTimeDelinquentAndGetPenaltyTime(100, 50), 0);
		assertEq(state.timeDelinquent, 100);

		// Cross over grace period, penalty on delta after crossing
		state.timeDelinquent = 99;
		state.isDelinquent = true;
		assertEq(state.updateTimeDelinquentAndGetPenaltyTime(100, 100), 99);
		assertEq(state.timeDelinquent, 199);

		// At grace period cutoff, penalty on full delta
		state.timeDelinquent = 100;
		state.isDelinquent = true;
		assertEq(state.updateTimeDelinquentAndGetPenaltyTime(100, 100), 100);
		assertEq(state.timeDelinquent, 200);

		// Past grace period cutoff, penalty on full delta
		state.timeDelinquent = 101;
		state.isDelinquent = true;
		assertEq(state.updateTimeDelinquentAndGetPenaltyTime(100, 100), 100);
		assertEq(state.timeDelinquent, 201);

		// Cross under grace period, penalty on delta before crossing
		state.timeDelinquent = 100;
		state.isDelinquent = false;
		assertEq(state.updateTimeDelinquentAndGetPenaltyTime(99, 100), 1);
		assertEq(state.timeDelinquent, 0);

		// Delinquent time = 50 seconds
		// Grace period = 50 seconds
		// Time elapsed = 50 seconds
		// Not delinquent
		// Should not apply penalty and decrease total by 50

		// Reach grace period cutoff, no penalty
		state.timeDelinquent = 50;
		state.isDelinquent = false;
		assertEq(state.updateTimeDelinquentAndGetPenaltyTime(100, 50), 0);
		assertEq(state.timeDelinquent, 0);

		state.timeDelinquent = 50;
		state.isDelinquent = false;
		assertEq(state.updateTimeDelinquentAndGetPenaltyTime(100, 100), 0);
		assertEq(state.timeDelinquent, 0);
	}
}
