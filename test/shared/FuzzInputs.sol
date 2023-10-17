// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'src/libraries/MathUtils.sol';
import { MarketState } from 'src/libraries/MarketState.sol';
import './TestConstants.sol';
import { bound } from '../helpers/VmUtils.sol';

using MathUtils for uint256;

using FuzzInputsLib for ConfigFuzzInputs global;
using FuzzInputsLib for StateFuzzInputs global;

// Used for fuzzing initial state for libraries
struct StateFuzzInputs {
  uint128 maxTotalSupply;
  uint128 accruedProtocolFees;
  uint128 normalizedUnclaimedWithdrawals;
  uint104 scaledTotalSupply;
  uint32 pendingWithdrawalExpiry;
  bool isDelinquent;
  uint32 timeDelinquent;
  uint16 annualInterestBips;
  uint16 reserveRatioBips;
  uint112 scaleFactor;
  uint32 lastInterestAccruedTimestamp;
}

// Used for fuzzing market deployment parameters
struct ConfigFuzzInputs {
  uint128 maxTotalSupply;
  uint16 protocolFeeBips;
  uint16 annualInterestBips;
  uint16 delinquencyFeeBips;
  uint32 withdrawalBatchDuration;
  uint16 reserveRatioBips;
  uint32 delinquencyGracePeriod;
  address feeRecipient;
}

library FuzzInputsLib {
  function constrain(ConfigFuzzInputs memory inputs) internal pure {
    inputs.annualInterestBips = uint16(
      bound(inputs.annualInterestBips, MinimumAnnualInterestBips, MaximumAnnualInterestBips)
    );
    inputs.delinquencyFeeBips = uint16(
      bound(inputs.delinquencyFeeBips, MinimumDelinquencyFeeBips, MaximumDelinquencyFeeBips)
    );
    inputs.withdrawalBatchDuration = uint32(
      bound(
        inputs.withdrawalBatchDuration,
        MinimumWithdrawalBatchDuration,
        MaximumWithdrawalBatchDuration
      )
    );
    inputs.reserveRatioBips = uint16(
      bound(inputs.reserveRatioBips, MinimumReserveRatioBips, MaximumReserveRatioBips)
    );
    inputs.delinquencyGracePeriod = uint32(
      bound(
        inputs.delinquencyGracePeriod,
        MinimumDelinquencyGracePeriod,
        MaximumDelinquencyGracePeriod
      )
    );
    if (inputs.protocolFeeBips > 0) {
      inputs.feeRecipient = address(
        uint160(bound(uint160(inputs.feeRecipient), 1, type(uint160).max))
      );
    }
  }

  function constrain(StateFuzzInputs memory inputs) internal view {
    inputs.scaleFactor = uint112(bound(inputs.scaleFactor, RAY, type(uint112).max));
    inputs.scaledTotalSupply = uint104(bound(inputs.scaledTotalSupply, 0, type(uint104).max));
    inputs.maxTotalSupply = uint128(
      bound(
        inputs.maxTotalSupply,
        uint256(inputs.scaledTotalSupply).rayMul(inputs.scaleFactor),
        type(uint128).max
      )
    );

    inputs.annualInterestBips = uint16(
      bound(inputs.annualInterestBips, MinimumAnnualInterestBips, MaximumAnnualInterestBips)
    );
    inputs.reserveRatioBips = uint16(
      bound(inputs.reserveRatioBips, MinimumReserveRatioBips, MaximumReserveRatioBips)
    );
    inputs.lastInterestAccruedTimestamp = uint32(
      bound(inputs.lastInterestAccruedTimestamp, 1, block.timestamp)
    );
    inputs.timeDelinquent = uint32(
      bound(inputs.timeDelinquent, 0, inputs.lastInterestAccruedTimestamp)
    );
  }

  function toState(StateFuzzInputs memory inputs) internal pure returns (MarketState memory state) {
    state.maxTotalSupply = inputs.maxTotalSupply;
    state.accruedProtocolFees = inputs.accruedProtocolFees;
    state.normalizedUnclaimedWithdrawals = inputs.normalizedUnclaimedWithdrawals;
    state.scaledTotalSupply = inputs.scaledTotalSupply;
    state.pendingWithdrawalExpiry = inputs.pendingWithdrawalExpiry;
    state.isDelinquent = inputs.isDelinquent;
    state.timeDelinquent = inputs.timeDelinquent;
    state.annualInterestBips = inputs.annualInterestBips;
    state.reserveRatioBips = inputs.reserveRatioBips;
    state.scaleFactor = inputs.scaleFactor;
    state.lastInterestAccruedTimestamp = inputs.lastInterestAccruedTimestamp;
  }
}
