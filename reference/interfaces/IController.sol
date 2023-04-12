// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IController {
	function canDeployVault(address borrower, address asset) external view returns (bool);

	function onDeployedVault(address borrower, address vault) external;
}
