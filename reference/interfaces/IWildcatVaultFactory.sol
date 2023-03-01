// SPDX-License-Identifier: NONE
pragma solidity ^0.8.17;

interface IWildcatVaultFactory {
	function getVaultParameters()
		external
		view
		returns (
			address _asset,
			string memory _namePrefix,
			string memory _symbolPrefix,
			address _owner,
			address _vaultPermissions,
			uint256 _maxTotalSupply,
			uint256 _annualInterestBips,
			uint256 _penaltyFeeBips,
			uint256 _gracePeriod,
			uint256 _collateralizationRatioBips,
			uint256 _interestFeeBips
		);

	function vaultRegistryAddress() external view returns (address);

	function vaultPermissionsAddress() external view returns (address);

	function isVaultValidated(address _controller, address _underlying)
		external
		view
		returns (bool);

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
