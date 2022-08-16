// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

interface IWMRegistry {
	function registerVault(address _newVault) external;

	function listVaults() external view returns (address[] memory);
}
