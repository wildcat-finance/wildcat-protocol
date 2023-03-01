// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import '../types/VaultSupplyCoder.sol';

// ============================== NOTICE ==============================
// This library was automatically generated with stackpacker.
// Be very careful about modifying it, as doing so incorrectly could
// result in corrupted reads/writes.
// ====================================================================

contract ExternalVaultSupplyCoder {
	VaultSupply internal _vaultSupply;

	function decode()
		external
		view
		returns (uint256 maxTotalSupply, uint256 scaledTotalSupply)
	{
		(maxTotalSupply, scaledTotalSupply) = VaultSupplyCoder.decode(_vaultSupply);
	}

	function encode(uint256 maxTotalSupply, uint256 scaledTotalSupply) external {
		(_vaultSupply) = VaultSupplyCoder.encode(maxTotalSupply, scaledTotalSupply);
	}

	function getMaxTotalSupply() external view returns (uint256 maxTotalSupply) {
		(maxTotalSupply) = VaultSupplyCoder.getMaxTotalSupply(_vaultSupply);
	}

	function setMaxTotalSupply(uint256 maxTotalSupply) external {
		(_vaultSupply) = VaultSupplyCoder.setMaxTotalSupply(
			_vaultSupply,
			maxTotalSupply
		);
	}

	function getScaledTotalSupply()
		external
		view
		returns (uint256 scaledTotalSupply)
	{
		(scaledTotalSupply) = VaultSupplyCoder.getScaledTotalSupply(_vaultSupply);
	}

	function setScaledTotalSupply(uint256 scaledTotalSupply) external {
		(_vaultSupply) = VaultSupplyCoder.setScaledTotalSupply(
			_vaultSupply,
			scaledTotalSupply
		);
	}
}
