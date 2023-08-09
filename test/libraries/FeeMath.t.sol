// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { FeeMath, MathUtils, SafeCastLib, VaultState } from 'reference/libraries/FeeMath.sol';
import '../shared/BaseTest.sol';

function maxRayMulRhs(uint256 left) pure returns (uint256 maxRight) {
	if (left == 0) return type(uint256).max;
	maxRight = (type(uint256).max - HALF_RAY) / left;
}

contract FeeMathTest is BaseTest {
	using MathUtils for uint256;
	using SafeCastLib for uint256;
	using FeeMath for VaultState;

	function testValidState(FuzzInput calldata inputs) external {
		VaultState memory state = getFuzzContext(inputs).state;
		uint256 vaultSupply = state.totalSupply();
		require(vaultSupply > 0);
	}

	// function testProtocolFees()

	function test_updateScaleFactorAndFees_WithFees() external {
		VaultState memory state;
		state.timeDelinquent = 1000;
		state.isDelinquent = true;
		uint256 delinquencyGracePeriod = 0;
		state.annualInterestBips = 1000;
		state.scaledTotalSupply = uint104(uint256(1e18).rayDiv(RAY));
		vm.warp(365 days);
		state.scaleFactor = uint112(RAY);
		// @todo fix
		// (uint256 feesAccrued, bool didUpdate) = state.calculateInterestAndFees(
		// 	1000,
		// 	0,
		// 	delinquencyGracePeriod
		// );
		// assertEq(state.lastInterestAccruedTimestamp, block.timestamp);
		// assertTrue(didUpdate, 'did not update');
		// assertEq(feesAccrued, 1e16, 'incorrect feesAccrued');
		// assertEq(state.scaleFactor, 1.09e27, 'incorrect scaleFactor');
	}

	function test_updateScaleFactorAndFees_WithoutFeesWithPenalties() external {
		VaultState memory state;
		state.timeDelinquent = 1000;
		state.isDelinquent = true;
		uint256 delinquencyGracePeriod = 0;
		state.annualInterestBips = 1000;
		state.scaledTotalSupply = uint104(uint256(1e18).rayDiv(RAY));
		vm.warp(365 days);
		state.scaleFactor = uint112(RAY);
		// @todo fix
		// (uint256 feesAccrued, bool didUpdate) = state.calculateInterestAndFees(
		// 	0,
		// 	1000,
		// 	delinquencyGracePeriod
		// );
		// assertEq(state.lastInterestAccruedTimestamp, block.timestamp);
		// assertTrue(didUpdate, 'did not update');
		// assertEq(feesAccrued, 0, 'incorrect feesAccrued');
		// assertEq(state.scaleFactor, 1.2e27, 'incorrect scaleFactor');
	}

	function test_updateScaleFactorAndFees_WithFeesAndPenalties() external {
		VaultState memory state;
		state.timeDelinquent = 1000;
		state.isDelinquent = true;
		uint256 delinquencyGracePeriod = 0;
		state.annualInterestBips = 1000;
		state.scaledTotalSupply = uint104(uint256(1e18).rayDiv(RAY));
		vm.warp(365 days);
		state.scaleFactor = uint112(RAY);
		// @todo fix
		(uint256 baseInterestRay, uint256 delinquencyFeeRay, uint256 protocolFee) = state.updateScaleFactorAndFees(
			1000,
			1000,
			delinquencyGracePeriod,
      block.timestamp
		);
		assertEq(state.lastInterestAccruedTimestamp, block.timestamp);
		
		assertEq(protocolFee, 1e16, 'incorrect feesAccrued');
		assertEq(state.scaleFactor, 1.2e27, 'incorrect scaleFactor');
    assertEq(baseInterestRay, 1e26, 'incorrect baseInterestRay');
    assertEq(delinquencyFeeRay, 1e26, 'incorrect delinquencyFeeRay');
	}

	function test_updateScaleFactorAndFees_WithoutFeesOrPenalties() external {
		VaultState memory state;
		state.timeDelinquent = 1000;
		state.isDelinquent = true;
		uint256 delinquencyGracePeriod = 0;
		state.annualInterestBips = 1000;
		state.scaledTotalSupply = uint104(uint256(1e18).rayDiv(RAY));
		vm.warp(365 days);
		state.scaleFactor = uint112(RAY);
		// (uint256 feesAccrued, bool didUpdate) = state.calculateInterestAndFees(
		// 	0,
		// 	0,
		// 	delinquencyGracePeriod
		// );
		// assertEq(state.lastInterestAccruedTimestamp, block.timestamp);
		// assertTrue(didUpdate, 'did not update');
		// assertEq(feesAccrued, 0, 'incorrect feesAccrued');
		// assertEq(state.scaleFactor, 1.1e27, 'incorrect scaleFactor');
	}

	function test_updateTimeDelinquentAndGetPenaltyTime(
		bool isCurrentlyDelinquent,
		uint32 previousTimeDelinquent,
		uint32 timeDelta,
		uint32 delinquencyGracePeriod
	) external {
		VaultState memory state;
		state.isDelinquent = isCurrentlyDelinquent;
		previousTimeDelinquent = uint32(bound(previousTimeDelinquent, 0, type(uint32).max - timeDelta));
		state.timeDelinquent = previousTimeDelinquent;

		uint256 timeWithPenalty = state.updateTimeDelinquentAndGetPenaltyTime(
			delinquencyGracePeriod,
			timeDelta
		);
		if (isCurrentlyDelinquent) {
			if (previousTimeDelinquent >= delinquencyGracePeriod) {
        // If already past grace period, full delta incurs penalty
				assertEq(timeWithPenalty, timeDelta, "should be full delta when past grace period");
			} else if (previousTimeDelinquent + timeDelta >= delinquencyGracePeriod) {
        // If delta crosses grace period, only the portion of the delta that is past the grace period incurs penalty
				assertEq(timeWithPenalty, (previousTimeDelinquent + timeDelta) - delinquencyGracePeriod, "incorrect partial delta when crossing grace period");
			} else {
        // If delta does not cross grace period, no penalty
				assertEq(timeWithPenalty, 0, "should be no penalty when not past grace period");
			}
      assertEq(state.timeDelinquent, previousTimeDelinquent + timeDelta, "incorrect timeDelinquent");
		} else {
      if (previousTimeDelinquent >= delinquencyGracePeriod) {
        uint32 timeLeftWithPenalty = previousTimeDelinquent - delinquencyGracePeriod;
        if (timeLeftWithPenalty >= timeDelta) {
          // If time left with penalty is greater than delta, full delta incurs penalty
          assertEq(timeWithPenalty, timeDelta, "should be full delta when time left with penalty is >= delta");
        } else {
          // If time left with penalty is less than delta, only the portion of the delta that is past the grace period incurs penalty
          assertEq(timeWithPenalty, timeLeftWithPenalty, "incorrect partial delta when time left with penalty is less than delta");
        }
      } else {
        // If not past grace period, no penalty
        assertEq(timeWithPenalty, 0, "should be no penalty when not past grace period");
      }

      if (previousTimeDelinquent <= timeDelta) {
        assertEq(state.timeDelinquent, 0, "incorrect timeDelinquent");
      } else  {
        assertEq(state.timeDelinquent, previousTimeDelinquent - timeDelta, "incorrect timeDelinquent");
      }
      
		}
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
