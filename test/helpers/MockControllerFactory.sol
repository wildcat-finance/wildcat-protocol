// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import 'src/WildcatVaultControllerFactory.sol';
import './MockController.sol';
import { MinimumDelinquencyGracePeriod as MinDelinquencyGracePeriod, MaximumDelinquencyGracePeriod as MaxDelinquencyGracePeriod, MinimumLiquidityCoverageRatio as MinLiquidityCoverageRatio, MaximumLiquidityCoverageRatio as MaxLiquidityCoverageRatio, MinimumDelinquencyFeeBips as MinDelinquencyFeeBips, MaximumDelinquencyFeeBips as MaxDelinquencyFeeBips, MinimumWithdrawalBatchDuration as MinWithdrawalBatchDuration, MaximumWithdrawalBatchDuration as MaxWithdrawalBatchDuration, MinimumAnnualInterestBips as MinAnnualInterestBips, MaximumAnnualInterestBips as MaxAnnualInterestBips, sentinel as SentinelAddress } from '../shared/TestConstants.sol';

contract MockControllerFactory is WildcatVaultControllerFactory {
  constructor(
    address _archController,
    address _sentinel
  )
    WildcatVaultControllerFactory(
      _archController,
      _sentinel,
      MinDelinquencyGracePeriod,
      MaxDelinquencyGracePeriod,
      MinLiquidityCoverageRatio,
      MaxLiquidityCoverageRatio,
      MinDelinquencyFeeBips,
      MaxDelinquencyFeeBips,
      MinWithdrawalBatchDuration,
      MaxWithdrawalBatchDuration,
      MinAnnualInterestBips,
      MaxAnnualInterestBips
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
