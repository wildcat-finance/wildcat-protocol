// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'src/libraries/Chainalysis.sol';
import './VmUtils.sol' as VmUtils;

contract MockChainalysis {
  mapping(address => bool) public isSanctioned;

  function sanction(address account) external {
    isSanctioned[account] = true;
  }

  function unsanction(address account) external {
    isSanctioned[account] = false;
  }
}

function deployMockChainalysis() {
  VmUtils.vm.etch(address(SanctionsList), type(MockChainalysis).runtimeCode);
}
