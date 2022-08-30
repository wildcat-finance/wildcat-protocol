// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

contract WildcatPermissions {
	address public controller;
	mapping(address => bool) public whitelisted;

	modifier isController() {
		require(msg.sender == controller, 'isController: not controller');
		_;
	}

	event ControllerAddressUpdated(address);
	event CounterpartyAdjustment(address, bool);

	constructor(address _controller) {
		controller = _controller;
		emit ControllerAddressUpdated(_controller);
	}

	function updateController(address _newController) external isController {
		controller = _newController;
		emit ControllerAddressUpdated(_newController);
	}

	function isWhitelisted(address _counterparty) external view returns (bool) {
		return whitelisted[_counterparty];
	}

	// Addresses that are whitelisted can mint wmtX via X
	// An address that is no longer whitelisted can redeem, but cannot mint more
	function adjustWhitelist(address _counterparty, bool _allowed)
		external
		isController
	{
		whitelisted[_counterparty] = _allowed;
		emit CounterpartyAdjustment(_counterparty, _allowed);
	}
}
