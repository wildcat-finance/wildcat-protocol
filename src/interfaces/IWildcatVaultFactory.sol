// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

interface IWildcatVaultFactory {

	function factoryVaultUnderlying() external returns (address);
	function factoryPermissionRegistry() external returns (address);
	function factoryVaultMaximumCapacity() external returns (uint256);
	function factoryVaultAnnualAPR() external returns (uint256);
	function factoryVaultCollatRatio() external returns (uint256);
    function factoryVaultInterestFeeBips() external view returns (uint256);
	function factoryVaultNamePrefix() external view returns (string memory);
	function factoryVaultSymbolPrefix() external view returns (string memory);

	function vaultRegistryAddress() external view returns (address);
	function vaultPermissionsAddress() external view returns (address);

	function vaultValidationFee() external view returns (uint256);
	function validateVaultDeployment(address _controller, address _underlying) external;
	function isVaultValidated(address _controller, address _underlying) external view returns (bool);
	function computeVaultAddress(bytes32 salt) external view returns (address);

	function deployVault(
		address _controller,
		address _underlying,
		uint256 _maxCapacity,
		uint256 _annualAPR,
		uint256 _collatRatio,
		string memory _namePrefix,
		string memory _symbolPrefix,
		bytes32 _salt
	) external returns (address vault);
}
