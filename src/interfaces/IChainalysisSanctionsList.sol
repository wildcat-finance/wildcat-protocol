// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

interface IChainalysisSanctionsList {
  function isSanctioned(address addr) external view returns (bool);
}
