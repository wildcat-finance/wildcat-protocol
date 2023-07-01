// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { VaultState } from "../libraries/VaultState.sol";
import { AuthRole } from "./WildcatStructsAndEnums.sol";

interface IVaultEventsAndErrors {
	/// @notice Error thrown when deposit exceeds maxTotalSupply
	error MaxSupplyExceeded();

	/// @notice Error thrown when non-borrower tries accessing borrower-only actions
	error NotApprovedBorrower();

	/// @notice Error thrown when non-approved lender tries lending to the vault
	error NotApprovedLender();

	/// @notice Error thrown when non-controller tries accessing controller-only actions
	error NotController();

	/// @notice Error thrown when non-sentinel tries to use nukeFromOrbit
	error BadLaunchCode();

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

	/// @notice Error thrown when transfer target is blacklisted
	error AccountBlacklisted();

	error UnknownNameQueryError();

	error UnknownSymbolQueryError();

	error BorrowAmountTooHigh();

	error FeeSetWithoutRecipient();

	error InsufficientCoverageForFeeWithdrawal();

	event Transfer(address indexed from, address indexed to, uint256 value);

	event Approval(address indexed owner, address indexed spender, uint256 value);

	event MaxSupplyUpdated(uint256 assets);

	event AnnualInterestBipsUpdated(uint256 annualInterestBipsUpdated);

	event LiquidityCoverageRatioUpdated(uint256 liquidityCoverageRatioUpdated);

	event Deposit(address indexed account, uint256 assetAmount, uint256 scaledAmount);

	event Withdrawal(address indexed account, uint256 assetAmount, uint256 scaledAmount);

	event Borrow(uint256 assetAmount);

	event VaultClosed(uint256 timestamp);

	event FeesCollected(uint256 assets);

	event StateUpdated(uint256 scaleFactor, bool isDelinquent);

	event ScaleFactorUpdated(
		uint256 scaleFactor,
		uint256 baseInterestRay,
		uint256 delinquencyFeeRay,
		uint256 protocolFee
	);

	event WithdrawalBatchExpired(
		uint256 expiry,
		uint256 scaledTotalAmount,
		uint256 scaledPaidAmount,
		uint256 normalizedPaidAmount
	);

  event WithdrawalBatchCreated(uint256 expiry, uint256 totalScaledAmount);

  event WithdrawalRequestCreated(
    uint256 expiry,
    address account,
    uint256 scaledAmount
  );

  event WithdrawalExecuted(
    uint256 expiry,
    address account,
    uint256 scaledAmount,
    uint256 normalizedAmount
  );

	event AuthorizationStatusUpdated(address indexed account, AuthRole role);
}
