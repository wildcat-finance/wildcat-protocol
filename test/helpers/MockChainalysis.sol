// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'src/libraries/Chainalysis.sol';
import * as VmUtils from './VmUtils.sol';

contract MockChainalysis {
	mapping(address => bool) public isSanctioned;

	function sanction(address account) external {
		isSanctioned[account] = true;
	}
}

function deployMockChainalysis() {
	VmUtils.vm.etch(address(SanctionsList), type(MockChainalysis).runtimeCode);
}
