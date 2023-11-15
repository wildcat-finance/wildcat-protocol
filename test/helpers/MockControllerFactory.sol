// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import 'src/WildcatMarketControllerFactory.sol';
import './MockController.sol';
import { MinimumDelinquencyGracePeriod as MinDelinquencyGracePeriod, MaximumDelinquencyGracePeriod as MaxDelinquencyGracePeriod, MinimumReserveRatioBips as MinReserveRatioBips, MaximumReserveRatioBips as MaxReserveRatioBips, MinimumDelinquencyFeeBips as MinDelinquencyFeeBips, MaximumDelinquencyFeeBips as MaxDelinquencyFeeBips, MinimumWithdrawalBatchDuration as MinWithdrawalBatchDuration, MaximumWithdrawalBatchDuration as MaxWithdrawalBatchDuration, MinimumAnnualInterestBips as MinAnnualInterestBips, MaximumAnnualInterestBips as MaxAnnualInterestBips } from '../shared/TestConstants.sol';

contract MockControllerFactory is WildcatMarketControllerFactory {
  constructor(
    address _archController,
    address _sentinel
  )
    WildcatMarketControllerFactory(
      _archController,
      _sentinel,
      MarketParameterConstraints(
        MinDelinquencyGracePeriod,
        MaxDelinquencyGracePeriod,
        MinReserveRatioBips,
        MaxReserveRatioBips,
        MinDelinquencyFeeBips,
        MaxDelinquencyFeeBips,
        MinWithdrawalBatchDuration,
        MaxWithdrawalBatchDuration,
        MinAnnualInterestBips,
        MaxAnnualInterestBips
      )
    )
  {}

  function _storeControllerInitCode()
    internal
    virtual
    override
    returns (address initCodeStorage, uint256 initCodeHash)
  {
    bytes memory controllerInitCode = type(MockController).creationCode;
    initCodeHash = uint256(keccak256(controllerInitCode));
    initCodeStorage = LibStoredInitCode.deployInitCode(controllerInitCode);
  }
}
