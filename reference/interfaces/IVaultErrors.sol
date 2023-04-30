// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IVaultErrors {
	/// @notice Error thrown when deposit exceeds maxTotalSupply
	error MaxSupplyExceeded();

	/// @notice Error thrown when non-borrower tries accessing borrower-only actions
	error NotBorrower();

	/// @notice Error thrown when non-controller tries accessing controller-only actions
	error NotController();

	/// @notice Error thrown when new maxTotalSupply lower than totalSupply
	error NewMaxSupplyTooLow();

	/// @notice Error thrown when liquidity coverage ratio set higher than 100%
	error LiquidityCoverageRatioTooHigh();

	/// @notice Error thrown when interest rate set higher than 100%
	error InterestRateTooHigh();

	/// @notice Error thrown when interest fee set higher than 100%
	error InterestFeeTooHigh();

	/// @notice Error thrown when penalty fee set higher than 100%
	error PenaltyFeeTooHigh();

	error UnknownNameQueryError();

	error UnknownSymbolQueryError();

  error BorrowAmountTooHigh();

  error FeeSetWithoutRecipient();

  error InsufficientCoverageForFeeWithdrawal();

	event Transfer(address indexed from, address indexed to, uint256 value);

	event Approval(address indexed owner, address indexed spender, uint256 value);

	event MaxSupplyUpdated(uint256 assets);

  event Deposit(address indexed account, uint256 assetAmount, uint256 scaledAmount);

  event Withdrawal(address indexed account, uint256 assetAmount, uint256 scaledAmount);

  event Borrow(uint256 assetAmount);

	event VaultClosed(uint256 timestamp);

	event FeesCollected(uint256 assets);
}
