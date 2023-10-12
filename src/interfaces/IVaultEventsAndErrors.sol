// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { VaultState } from '../libraries/VaultState.sol';
import { AuthRole } from './WildcatStructsAndEnums.sol';

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

  /// @notice Error thrown when reserve ratio set higher than 100%
  error ReserveRatioBipsTooHigh();

  /// @notice Error thrown when interest rate set higher than 100%
  error InterestRateTooHigh();

  /// @notice Error thrown when interest fee set higher than 100%
  error InterestFeeTooHigh();

  /// @notice Error thrown when penalty fee set higher than 100%
  error PenaltyFeeTooHigh();

  /// @notice Error thrown when transfer target is blacklisted
  error AccountBlacklisted();

  error AccountNotBlocked();

  error NotReversedOrStunning();

  error UnknownNameQueryError();

  error UnknownSymbolQueryError();

  error BorrowAmountTooHigh();

  error FeeSetWithoutRecipient();

  error InsufficientReservesForFeeWithdrawal();

  error WithdrawalBatchNotExpired();

  error NullMintAmount();

  error NullBurnAmount();

  error NullFeeAmount();

  error NullTransferAmount();

  error NullWithdrawalAmount();

  error DepositToClosedVault();

  error BorrowFromClosedVault();

  error CloseVaultWithUnpaidWithdrawals();

  /// @notice Error thrown when reserve ratio set to value
  ///         the vault currently would not meet.
  error InsufficientReservesForNewLiquidityRatio();

  error InsufficientReservesForOldLiquidityRatio();

  event Transfer(address indexed from, address indexed to, uint256 value);

  event Approval(address indexed owner, address indexed spender, uint256 value);

  event MaxTotalSupplyUpdated(uint256 assets);

  event AnnualInterestBipsUpdated(uint256 annualInterestBipsUpdated);

  event ReserveRatioBipsUpdated(uint256 reserveRatioBipsUpdated);

  event SanctionedAccountAssetsSentToEscrow(address account, address escrow, uint256 amount);

  event Deposit(address indexed account, uint256 assetAmount, uint256 scaledAmount);

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

  event AuthorizationStatusUpdated(address indexed account, AuthRole role);

  // =====================================================================//
  //                          Withdrawl Events                            //
  // =====================================================================//

  event WithdrawalBatchExpired(
    uint256 expiry,
    uint256 scaledTotalAmount,
    uint256 scaledAmountBurned,
    uint256 normalizedAmountPaid
  );

  /**
   * @dev Emitted when a new withdrawal batch is created.
   */
  event WithdrawalBatchCreated(uint256 expiry);

  /**
   * @dev Emitted when a withdrawal batch is paid off.
   */
  event WithdrawalBatchClosed(uint256 expiry);

  event WithdrawalBatchPayment(
    uint256 expiry,
    uint256 scaledAmountBurned,
    uint256 normalizedAmountPaid
  );

  event WithdrawalQueued(uint256 expiry, address account, uint256 scaledAmount);

  event WithdrawalExecuted(uint256 expiry, address account, uint256 normalizedAmount);

  event Withdrawal(address indexed account, uint256 assetAmount, uint256 scaledAmount);

  event SanctionedAccountWithdrawalSentToEscrow(
    address account,
    address escrow,
    uint32 expiry,
    uint256 amount
  );
}
