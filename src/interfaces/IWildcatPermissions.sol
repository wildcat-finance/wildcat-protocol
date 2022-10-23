// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

interface IWildcatPermissions {
	function onDeployVault(
		address deployer,
		address asset,
		address vault,
		uint256 collateralizationRatioBips,
		uint256 annualInterestBips
	) external;

	function getInterestFeeBips(
		address deployer,
		address asset,
		address vault
	) external view returns (uint256);

	function archController() external view returns (address);

	function updateArchController(address _newArchController) external;

	function archRecipient() external view returns (address);

	function updateArchRecipient(address _newArchRecipient) external;

	function addApprovedController(address _controller) external;

	function isApprovedController(address _controller)
		external
		view
		returns (bool);

	function registerVaultController(address _vault, address _controller)
		external;

	function modifyVaultController(address _vault, address _newController)
		external;

	function isVaultController(address _vault) external view returns (address);

	function adjustWhitelist(address _counterparty, bool _allowed) external;

	function isWhitelisted(address _vault, address _counterparty)
		external
		view
		returns (bool);
}
