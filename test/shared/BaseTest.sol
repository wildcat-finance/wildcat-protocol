// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { FeeMath, MathUtils, SafeCastLib, MarketState, HALF_RAY, RAY } from 'src/libraries/FeeMath.sol';
import 'solmate/test/utils/mocks/MockERC20.sol';
import { WildcatMarketController } from 'src/WildcatMarketController.sol';
import { WildcatMarket, MarketParameters } from 'src/market/WildcatMarket.sol';
import { MockController } from '../helpers/MockController.sol';
import { ConfigFuzzInputs, StateFuzzInputs } from './FuzzInputs.sol';
import './TestConstants.sol';
import './Test.sol';

struct FuzzInput {
  StateFuzzInputs state;
  uint256 reserveRatioBips;
  uint256 protocolFeeBips;
  uint256 delinquencyFeeBips;
  uint256 delinquencyGracePeriod;
  uint256 timeDelta;
}

struct FuzzContext {
  MarketState state;
  uint256 reserveRatioBips;
  uint256 protocolFeeBips;
  uint256 delinquencyFeeBips;
  uint256 delinquencyGracePeriod;
  uint256 timeDelta;
}

contract BaseTest is Test {
  using MathUtils for uint256;
  using SafeCastLib for uint256;

  MockERC20 internal asset;

  function deployMarket(ConfigFuzzInputs memory inputs) internal returns (WildcatMarket market) {
    asset = new MockERC20('Token', 'TKN', 18);
    MarketParameters memory parameters = getMarketParameters(inputs);

    deployControllerAndMarket(parameters, true, false);
  }

  function getMarketParameters(
    ConfigFuzzInputs memory inputs
  ) internal view returns (MarketParameters memory parameters) {
    inputs.constrain();
    parameters = MarketParameters({
      asset: address(asset),
      namePrefix: 'Wildcat ',
      symbolPrefix: 'WC',
      borrower: borrower,
      controller: controllerFactory.computeControllerAddress(borrower),
      feeRecipient: inputs.feeRecipient,
      sentinel: address(sanctionsSentinel),
      maxTotalSupply: inputs.maxTotalSupply,
      protocolFeeBips: inputs.protocolFeeBips,
      annualInterestBips: inputs.annualInterestBips,
      delinquencyFeeBips: inputs.delinquencyFeeBips,
      withdrawalBatchDuration: inputs.withdrawalBatchDuration,
      reserveRatioBips: inputs.reserveRatioBips,
      delinquencyGracePeriod: inputs.delinquencyGracePeriod
    });
  }

  function getMarketState(
    StateFuzzInputs memory inputs
  ) internal view returns (MarketState memory state) {
    inputs.constrain();
    return inputs.toState();
  }

  function maxRayMulRhs(uint256 left) internal pure returns (uint256 maxRight) {
    if (left == 0) return type(uint256).max;
    maxRight = (type(uint256).max - HALF_RAY) / left;
  }

  function getFuzzContext(FuzzInput calldata input) internal returns (FuzzContext memory context) {
    context.state = getMarketState(input.state);
    context.reserveRatioBips = bound(input.reserveRatioBips, 1, 1e4).toUint16();
    context.protocolFeeBips = bound(input.protocolFeeBips, 1, 1e4).toUint16();
    context.delinquencyFeeBips = bound(input.delinquencyFeeBips, 1, 1e4).toUint16();
    context.delinquencyGracePeriod = input.delinquencyGracePeriod;
    context.timeDelta = bound(input.timeDelta, 0, type(uint32).max);
    uint256 currentBlockTime = bound(block.timestamp, context.timeDelta, type(uint32).max);
    vm.warp(currentBlockTime);
    context.state.lastInterestAccruedTimestamp = uint32(currentBlockTime - context.timeDelta);
  }
}
