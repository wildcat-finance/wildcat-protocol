// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

contract WildcatPermissions {
	address public archController;
	mapping(address => bool) public approvedController;
	mapping(address => address) public vaultController;

	mapping(address => mapping(address => bool)) public whitelisted;

	modifier isArchController() {
		require((msg.sender == archController), 'isArchController: inappropriate permissions');
		_;
	}

	event ArchControllerAddressUpdated(address);
	event CounterpartyAdjustment(address, address, bool);
	event ApprovedControllerAdded(address);
	event VaultControllerRegistered(address, address);

	constructor(address _archcontroller) {
		archController = _archcontroller;
		emit ArchControllerAddressUpdated(_archcontroller);
	}

	function updateArchController(address _newArchController) external isArchController {
		archController = _newArchController;
		emit ArchControllerAddressUpdated(_newArchController);
	}

	function addApprovedController(address _controller) external isArchController {
		approvedController[_controller] = true;
		emit ApprovedControllerAdded(_controller);
	}

	function isApprovedController(address _controller) external view returns (bool) {
		return approvedController[_controller];
	}

	function registerVaultController(address _vault, address _controller) external {
		require(vaultController[_vault] == address(0x00)
			&& approvedController[_controller], "inappropriate permissions");
		vaultController[_vault] = _controller;
		emit VaultControllerRegistered(_vault, _controller);
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
