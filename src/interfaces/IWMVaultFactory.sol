// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

interface IWMVaultFactory {
	function factoryVaultUnderlying() external returns (address);

	function factoryPermissionRegistry() external returns (address);

	function factoryVaultMaximumCapacity() external returns (uint256);

	function factoryVaultAnnualAPR() external returns (int256);

	function factoryVaultCollatRatio() external returns (uint256);

	function vaultRegistryAddress() external view returns (address);

	function vaultPermissionsAddress() external view returns (address);
}
