// SPDX-License-Identifier: NONE
pragma solidity ^0.8.17;

interface IWildcatRegistry {
	function registerVault(address _newVault) external;

	function listVaults() external view returns (address[] memory);
}
