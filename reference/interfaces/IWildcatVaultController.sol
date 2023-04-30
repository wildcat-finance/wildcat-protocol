// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './IWildcatVaultFactory.sol';

interface IWildcatVaultController {
	function getVaultParameters(
		address /* deployer */,
		VaultParameters memory vaultParameters
	) external view returns (VaultParameters memory);

	function handleDeployVault(
		address vault,
		address deployer,
		VaultParameters memory vaultParameters
	) external returns (VaultParameters memory);
}
