// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { FeeMath, MathUtils, SafeCastLib, VaultState } from 'src/libraries/FeeMath.sol';
import '../shared/BaseTest.sol';
import './wrappers/FeeMathExternal.sol';

function maxRayMulRhs(uint256 left) pure returns (uint256 maxRight) {
  if (left == 0) return type(uint256).max;
  maxRight = (type(uint256).max - HALF_RAY) / left;
}

// Uses an external wrapper library to make forge coverage work for FeeMath.
// Forge is currently incapable of mapping MemberAccess function calls with
// expressions other than library identifiers (e.g. value.x() vs XLib.x(value))
// to the correct FunctionDefinition nodes.
contract FeeMathTest is BaseTest {
  using MathUtils for uint256;
  using SafeCastLib for uint256;
  using FeeMathExternal for VaultState;

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
    uint256 baseInterestRay;
    uint256 delinquencyFeeRay;
    uint256 protocolFee;
    // @todo fix
    (state, baseInterestRay, delinquencyFeeRay, protocolFee) = state.$updateScaleFactorAndFees(
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

  function test_updateScaleFactorAndFees_NoTimeDelta(
    ConfigFuzzInputs calldata configInputs,
    StateFuzzInputs calldata stateInputs
  ) external {
    VaultParameters memory parameters = getVaultParameters(configInputs);
    VaultState memory state = getVaultState(stateInputs);
    bytes32 stateHash = keccak256(abi.encode(state));
    uint256 baseInterestRay;
    uint256 delinquencyFeeRay;
    uint256 protocolFee;
    (state, baseInterestRay, delinquencyFeeRay, protocolFee) = state.$updateScaleFactorAndFees(
      parameters.protocolFeeBips,
      parameters.delinquencyFeeBips,
      parameters.delinquencyGracePeriod,
      state.lastInterestAccruedTimestamp
    );
    assertEq(baseInterestRay, 0, 'incorrect baseInterestRay');
    assertEq(delinquencyFeeRay, 0, 'incorrect delinquencyFeeRay');
    assertEq(protocolFee, 0, 'incorrect protocolFee');
    assertEq(keccak256(abi.encode(state)), stateHash, 'state should not change');
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

    uint256 timeWithPenalty;
    (state, timeWithPenalty) = state.$updateTimeDelinquentAndGetPenaltyTime(
      delinquencyGracePeriod,
      timeDelta
    );
    if (isCurrentlyDelinquent) {
      if (previousTimeDelinquent >= delinquencyGracePeriod) {
        // If already past grace period, full delta incurs penalty
        assertEq(timeWithPenalty, timeDelta, 'should be full delta when past grace period');
      } else if (previousTimeDelinquent + timeDelta >= delinquencyGracePeriod) {
        // If delta crosses grace period, only the portion of the delta that is past the grace period incurs penalty
        assertEq(
          timeWithPenalty,
          (previousTimeDelinquent + timeDelta) - delinquencyGracePeriod,
          'incorrect partial delta when crossing grace period'
        );
      } else {
        // If delta does not cross grace period, no penalty
        assertEq(timeWithPenalty, 0, 'should be no penalty when not past grace period');
      }
      assertEq(
        state.timeDelinquent,
        previousTimeDelinquent + timeDelta,
        'incorrect timeDelinquent'
      );
    } else {
      if (previousTimeDelinquent >= delinquencyGracePeriod) {
        uint32 timeLeftWithPenalty = previousTimeDelinquent - delinquencyGracePeriod;
        if (timeLeftWithPenalty >= timeDelta) {
          // If time left with penalty is greater than delta, full delta incurs penalty
          assertEq(
            timeWithPenalty,
            timeDelta,
            'should be full delta when time left with penalty is >= delta'
          );
        } else {
          // If time left with penalty is less than delta, only the portion of the delta that is past the grace period incurs penalty
          assertEq(
            timeWithPenalty,
            timeLeftWithPenalty,
            'incorrect partial delta when time left with penalty is less than delta'
          );
        }
      } else {
        // If not past grace period, no penalty
        assertEq(timeWithPenalty, 0, 'should be no penalty when not past grace period');
      }

      if (previousTimeDelinquent <= timeDelta) {
        assertEq(state.timeDelinquent, 0, 'incorrect timeDelinquent');
      } else {
        assertEq(
          state.timeDelinquent,
          previousTimeDelinquent - timeDelta,
          'incorrect timeDelinquent'
        );
      }
    }
  }

  function testUpdateTimeDelinquentAndGetPenaltyTime() external {
    VaultState memory state;
    uint256 timeWithPenalty;
    // Within grace period, no penalty
    state.timeDelinquent = 50;
    state.isDelinquent = true;
    (state, timeWithPenalty) = state.$updateTimeDelinquentAndGetPenaltyTime(100, 25);
    assertEq(timeWithPenalty, 0);
    assertEq(state.timeDelinquent, 75);

    // Reach grace period cutoff, no penalty
    state.timeDelinquent = 50;
    state.isDelinquent = true;
    (state, timeWithPenalty) = state.$updateTimeDelinquentAndGetPenaltyTime(100, 50);
    assertEq(timeWithPenalty, 0);
    assertEq(state.timeDelinquent, 100);

    // Cross over grace period, penalty on delta after crossing
    state.timeDelinquent = 99;
    state.isDelinquent = true;
    (state, timeWithPenalty) = state.$updateTimeDelinquentAndGetPenaltyTime(100, 100);
    assertEq(timeWithPenalty, 99);
    assertEq(state.timeDelinquent, 199);

    // At grace period cutoff, penalty on full delta
    state.timeDelinquent = 100;
    state.isDelinquent = true;
    (state, timeWithPenalty) = state.$updateTimeDelinquentAndGetPenaltyTime(100, 100);
    assertEq(timeWithPenalty, 100);
    assertEq(state.timeDelinquent, 200);

    // Past grace period cutoff, penalty on full delta
    state.timeDelinquent = 101;
    state.isDelinquent = true;
    (state, timeWithPenalty) = state.$updateTimeDelinquentAndGetPenaltyTime(100, 100);
    assertEq(timeWithPenalty, 100);
    assertEq(state.timeDelinquent, 201);

    // Cross under grace period, penalty on delta before crossing
    state.timeDelinquent = 100;
    state.isDelinquent = false;
    (state, timeWithPenalty) = state.$updateTimeDelinquentAndGetPenaltyTime(99, 100);
    assertEq(timeWithPenalty, 1);
    assertEq(state.timeDelinquent, 0);

    // Reach grace period cutoff, no penalty
    state.timeDelinquent = 50;
    state.isDelinquent = false;
    (state, timeWithPenalty) = state.$updateTimeDelinquentAndGetPenaltyTime(100, 50);
    assertEq(timeWithPenalty, 0);
    assertEq(state.timeDelinquent, 0);

    state.timeDelinquent = 50;
    state.isDelinquent = false;
    (state, timeWithPenalty) = state.$updateTimeDelinquentAndGetPenaltyTime(100, 100);
    assertEq(timeWithPenalty, 0);
    assertEq(state.timeDelinquent, 0);
  }
}
