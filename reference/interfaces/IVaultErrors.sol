// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IVaultErrors {
	/// @notice Error thrown when deposit exceeds maxTotalSupply
	error MaxSupplyExceeded();

	/// @notice Error thrown when non-owner tries accessing owner-only actions
	error NotOwner();

	/// @notice Error thrown when new maxTotalSupply lower than totalSupply
	error NewMaxSupplyTooLow();

	/// @notice Error thrown when collateralization ratio higher than 100%
	error CollateralizationRatioTooHigh();

	/// @notice Error thrown when interest fee set higher than 100%
	error InterestFeeTooHigh();

	error UnknownNameQueryError();

	error UnknownSymbolQueryError();

	event Transfer(address indexed from, address indexed to, uint256 value);

	event Approval(address indexed owner, address indexed spender, uint256 value);

	event MaxSupplyUpdated(uint256 assets);
}
