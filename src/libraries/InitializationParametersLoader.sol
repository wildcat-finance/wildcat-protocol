// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../interfaces/IWildcatVaultFactory.sol';

contract InitializationParametersLoader {
	constructor() {
		IWildcatVaultFactory(msg.sender).getVaultParameters();
	}
}

uint256 constant metadataReturnDataOffset = 0x00;
uint256 constant metadataReturnDataLength = 0x60;
uint256 constant vaultConfigReturnDataOffset = 0x60;
uint256 constant vaultConfigReturnDataLength = 0xc0;

function loadMetadataInitializationParameters()
	pure
	returns (
		address asset,
		bytes32 packedNamePrefix,
		bytes32 packedSymbolPrefix
	)
{
	assembly {
		let freeMemPtr := mload(0x40)
		mstore(freeMemPtr, add(freeMemPtr, metadataReturnDataLength))
		returndatacopy(
			freeMemPtr,
			metadataReturnDataOffset,
			metadataReturnDataLength
		)
		asset := mload(freeMemPtr)
		packedNamePrefix := add(freeMemPtr, 0x20)
		packedSymbolPrefix := add(freeMemPtr, 0x40)
	}
}

function loadVaultConfigInitializationParameters()
	pure
	returns (
		address owner,
		address vaultPermissions,
		uint256 maxTotalSupply,
		uint256 annualInterestBips,
		uint256 collateralizationRatioBips,
		uint256 interestFeeBips
	)
{
	assembly {
		let freeMemPtr := mload(0x40)
		mstore(freeMemPtr, add(freeMemPtr, vaultConfigReturnDataLength))
		returndatacopy(
			freeMemPtr,
			vaultConfigReturnDataOffset,
			vaultConfigReturnDataLength
		)
		owner := mload(freeMemPtr)
		vaultPermissions := mload(add(freeMemPtr, 0x20))
		maxTotalSupply := mload(add(freeMemPtr, 0x40))
		annualInterestBips := mload(add(freeMemPtr, 0x60))
		collateralizationRatioBips := mload(add(freeMemPtr, 0x80))
		interestFeeBips := mload(add(freeMemPtr, 0xa0))
	}
}
