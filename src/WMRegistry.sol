// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import './WMVault.sol';

contract WMRegistry {
	address[] public wmVaults;

	// EnumerableSet.AddressSet internal vaults; // do we want this?

	function registerVault(address _newVault) external {
		wmVaults.push(_newVault);
	}

	function listVaults() external view returns (address[] memory) {
		return wmVaults;
	}
}
