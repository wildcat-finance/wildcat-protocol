// SPDX-License-Identifier: NONE
pragma solidity ^0.8.17;

enum AuthorizableAction {
	RECEIVE,
	DEPOSIT,
	WITHDRAW
}

interface IWildcatPermissions {
	function onDeployVault(
		address deployer,
		address asset,
		address vault,
		uint256 liquidityCoverageRatio,
		uint256 annualInterestBips
	) external;

	function getprotocolFeeBips(
		address deployer,
		address asset,
		address vault
	) external view returns (uint256);

	function archController() external view returns (address);

	function updateArchController(address _newArchController) external;

	function archRecipient() external view returns (address);

	function updateArchRecipient(address _newArchRecipient) external;

	function addApprovedController(address _controller) external;

	function isApprovedController(
		address _controller
	) external view returns (bool);

	function registerVaultController(
		address _vault,
		address _controller
	) external;

	function modifyVaultController(
		address _vault,
		address _newController
	) external;

	function isVaultController(address _vault) external view returns (address);

	function adjustWhitelist(address _counterparty, bool _allowed) external;

	function getAuthorizationRequirements()
		external
		view
		returns (
			bool checkAuthOnReceive,
			bool checkAuthOnDeposit,
			bool checkAuthOnWithdraw
		);

	function checkAuthorization(
		AuthorizableAction action,
		address account
	) external view returns (bool);

	function checkAuthorizations(
		AuthorizableAction[] calldata action,
		address[] calldata account
	) external view returns (bool);

	function getAuthorizations(
		AuthorizableAction[] calldata action,
		address[] calldata account
	) external view returns (bool[] memory);

	function isWhitelisted(
		address _vault,
		address _counterparty
	) external view returns (bool);
}
