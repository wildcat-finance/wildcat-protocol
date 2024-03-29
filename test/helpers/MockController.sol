// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20;

import 'src/WildcatMarketController.sol';

contract MockController is WildcatMarketController {
  using EnumerableSet for EnumerableSet.AddressSet;

  bool public AUTH_ALL;
  bool public DISABLE_PARAMETER_CHECKS;

  function toggleParameterChecks() external {
    DISABLE_PARAMETER_CHECKS = true;
  }

  function authorizeAll() external {
    AUTH_ALL = true;
  }

  function isAuthorizedLender(address lender) external view virtual override returns (bool) {
    if (AUTH_ALL) {
      return true;
    }
    return _authorizedLenders.contains(lender);
  }

  function enforceParameterConstraints(
    string memory namePrefix,
    string memory symbolPrefix,
    uint16 annualInterestBips,
    uint16 delinquencyFeeBips,
    uint32 withdrawalBatchDuration,
    uint16 reserveRatioBips,
    uint32 delinquencyGracePeriod
  ) internal view virtual override {
    if (!DISABLE_PARAMETER_CHECKS) {
      super.enforceParameterConstraints(
        namePrefix,
        symbolPrefix,
        annualInterestBips,
        delinquencyFeeBips,
        withdrawalBatchDuration,
        reserveRatioBips,
        delinquencyGracePeriod
      );
    }
  }
}
