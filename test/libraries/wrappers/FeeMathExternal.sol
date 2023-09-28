pragma solidity ^0.8.20;

import { FeeMath } from 'src/libraries/FeeMath.sol';
import { VaultState } from 'src/libraries/VaultState.sol';

library FeeMathExternal {
  function $calculateLinearInterestFromBips(
    uint256 rateBip,
    uint256 timeDelta
  ) external pure returns (uint256 result) {
    return FeeMath.calculateLinearInterestFromBips(rateBip, timeDelta);
  }

  function $calculateBaseInterest(
    VaultState memory state,
    uint256 timestamp
  ) external pure returns (uint256 baseInterestRay) {
    return FeeMath.calculateBaseInterest(state, timestamp);
  }

  function $applyProtocolFee(
    VaultState memory state,
    uint256 baseInterestRay,
    uint256 protocolFeeBips
  ) external pure returns (VaultState memory newState, uint256 protocolFee) {
    protocolFee = FeeMath.applyProtocolFee(state, baseInterestRay, protocolFeeBips);
    newState = state;
  }

  function $updateDelinquency(
    VaultState memory state,
    uint256 timestamp,
    uint256 delinquencyFeeBips,
    uint256 delinquencyGracePeriod
  ) external pure returns (VaultState memory newState, uint256 delinquencyFeeRay) {
    newState = state;
    delinquencyFeeRay = FeeMath.updateDelinquency(
      state,
      timestamp,
      delinquencyFeeBips,
      delinquencyGracePeriod
    );
  }

  function $updateTimeDelinquentAndGetPenaltyTime(
    VaultState memory state,
    uint256 delinquencyGracePeriod,
    uint256 timeDelta
  ) external pure returns (VaultState memory newState, uint256 timeWithPenalty) {
    newState = state;
    timeWithPenalty = FeeMath.updateTimeDelinquentAndGetPenaltyTime(
      state,
      delinquencyGracePeriod,
      timeDelta
    );
  }

  function $updateScaleFactorAndFees(
    VaultState memory state,
    uint256 protocolFeeBips,
    uint256 delinquencyFeeBips,
    uint256 delinquencyGracePeriod,
    uint256 timestamp
  )
    external
    pure
    returns (
      VaultState memory newState,
      uint256 baseInterestRay,
      uint256 delinquencyFeeRay,
      uint256 protocolFee
    )
  {
    newState = state;
    (baseInterestRay, delinquencyFeeRay, protocolFee) = FeeMath.updateScaleFactorAndFees(
      state,
      protocolFeeBips,
      delinquencyFeeBips,
      delinquencyGracePeriod,
      timestamp
    );
  }
}
