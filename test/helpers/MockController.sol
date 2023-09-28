// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import 'src/WildcatVaultController.sol';

contract MockController is WildcatVaultController {
  constructor(
    address _feeRecipient,
    address _factory
  ) WildcatVaultController(_feeRecipient, _factory) {}

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
    return _authorizedLenders[lender];
  }

  function getFinalVaultParameters(
    address deployer,
    VaultParameters memory vaultParameters
  ) public view virtual override returns (VaultParameters memory) {
    if (DISABLE_PARAMETER_CHECKS) {
      return vaultParameters;
    }
    return super.getFinalVaultParameters(deployer, vaultParameters);
  }
}
