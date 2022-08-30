// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import './WMVault.sol';

contract WildcatRegistry {
	address[] public wildcatVaults;

	function registerVault(address _newVault) external {
		wildcatVaults.push(_newVault);
	}

	function listVaults() external view returns (address[] memory) {
		return wildcatVaults;
	}
}
