// SPDX-License-Identifier: NONE
pragma solidity ^0.8.17;

struct VaultParameters {
	address asset;
	string namePrefix;
	string symbolPrefix;
	address owner;
	address controller;
	uint256 maxTotalSupply;
	uint256 annualInterestBips;
	uint256 penaltyFeeBips;
	uint256 gracePeriod;
	uint256 liquidityCoverageRatio;
	uint256 interestFeeBips;
}

interface IWildcatVaultFactory {
	function getVaultParameters() external view returns (VaultParameters memory);

	function vaultRegistryAddress() external view returns (address);

	function controllerAddress() external view returns (address);

	function isVaultValidated(
		address _controller,
		address _underlying
	) external view returns (bool);

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
