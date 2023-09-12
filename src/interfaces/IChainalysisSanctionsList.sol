// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IChainalysisSanctionsList {
	function isSanctioned(address addr) external view returns (bool);
}
