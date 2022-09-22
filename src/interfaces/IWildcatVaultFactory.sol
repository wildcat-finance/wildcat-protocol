// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

interface IWildcatVaultFactory {
	function getVaultParameters() external view returns (
		address asset,
		bytes32 namePrefix,
		bytes32 symbolPrefix,
		address owner,
		address vaultPermissions,
		uint256 maxTotalSupply,
		uint256 annualInterestBips,
		uint256 collateralizationRatioBips,
		uint256 interestFeeBips
	);

	function vaultRegistryAddress() external view returns (address);
	function vaultPermissionsAddress() external view returns (address);
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
