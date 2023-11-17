// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

contract MockChainalysis {
  mapping(address => bool) public isSanctioned;

  function sanction(address account) external {
    isSanctioned[account] = true;
  }

  function unsanction(address account) external {
    isSanctioned[account] = false;
  }
}