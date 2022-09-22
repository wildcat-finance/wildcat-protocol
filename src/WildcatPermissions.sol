// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import "./libraries/SafeTransferLib.sol";

contract WildcatPermissions {
	using SafeTransferLib for address;

	address public archController;
	address public archRecipient;
	uint256 public immutable interestFeeBips;
	address public feeAsset;
	uint256 public deployVaultFee;
	mapping(address => bool) public approvedController;
	mapping(address => mapping(address => bool)) public approvedForAsset;
	mapping(address => address) public vaultController;

	mapping(address => mapping(address => bool)) public whitelisted;

	modifier isArchController() {
		require((msg.sender == archController), 'isArchController: inappropriate permissions');
		_;
	}

	event ArchControllerAddressUpdated(address);
	event ArchRecipientAddressUpdated(address);
	event CounterpartyAdjustment(address, address, bool);
	event ApprovedControllerAdded(address);
	event VaultControllerRegistered(address, address);
	event VaultControllerModified(address, address);

	constructor(address _archcontroller, uint256 _interestFeeBips) {
		interestFeeBips = _interestFeeBips;
		archController = _archcontroller;
		archRecipient = _archcontroller;
		emit ArchControllerAddressUpdated(_archcontroller);
		emit ArchRecipientAddressUpdated(_archcontroller);
	}

	function onDeployVault(
		address deployer,
		address asset,
		address /* vault */,
		uint256 collateralizationRatioBips,
		uint256 /* annualInterestBips */
	) external {
		require(approvedController[deployer], "Not Approved");
		feeAsset.safeTransferFrom(deployer, address(this), deployVaultFee);
		require(collateralizationRatioBips > 0, "Collat = 0");
	}

	function approveForAsset(address deployer, address vault) external isArchController {
		approvedForAsset[deployer][vault] = true;
	}

	function getInterestFeeBips(address /* deployer */, address /* asset */, address /* vault */) external view returns (uint256) {
		return interestFeeBips;
	}

	function updateArchController(address _newArchController) external isArchController {
		archController = _newArchController;
		emit ArchControllerAddressUpdated(_newArchController);
	}

	function updateArchRecipient(address _newArchRecipient) external isArchController {
		archRecipient = _newArchRecipient;
		emit ArchRecipientAddressUpdated(_newArchRecipient);
	}

	function addApprovedController(address _controller) external isArchController {
		approvedController[_controller] = true;
		emit ApprovedControllerAdded(_controller);
	}

	function isApprovedController(address _controller) external view returns (bool) {
		return approvedController[_controller];
	}

	// NOTE: this currently enables bypass of vault registration fee if you calculate the vault address in advance
	// NOTE: perhaps introduce a variable that flips on and off during vault creation within the factory
	// NOTE: [would require a variable in here dictating the address of the vault factory]
	function registerVaultController(address _vault, address _controller) external {
		require(vaultController[_vault] == address(0x00)
			 && approvedController[_controller], "registerVaultController: inappropriate permissions");
		vaultController[_vault] = _controller;
		emit VaultControllerRegistered(_vault, _controller);
	}

	function modifyVaultController(address _vault, address _newController) external isArchController {
		require(vaultController[_vault] != address(0x00)
			 && approvedController[_newController], "modifyVaultController: inappropriate permissions");
		vaultController[_vault] = _newController;
		emit VaultControllerModified(_vault, _newController);
	}

	function isVaultController(address _vault) external view returns (address) {
		return vaultController[_vault];
	}

	function isWhitelisted(address _vault, address _counterparty) external view returns (bool) {
		return whitelisted[_vault][_counterparty];
	}

	// Addresses that are whitelisted can mint
	// An address that is no longer whitelisted can redeem, but cannot mint more
	function adjustWhitelist(address _vault, address _counterparty, bool _allowed)
		external
		isArchController
	{
		whitelisted[_vault][_counterparty] = _allowed;
		emit CounterpartyAdjustment(_vault, _counterparty, _allowed);
	}
}
