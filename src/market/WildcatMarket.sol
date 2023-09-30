// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../libraries/FeeMath.sol';
import './WildcatMarketBase.sol';
import './WildcatMarketConfig.sol';
import './WildcatMarketToken.sol';
import './WildcatMarketWithdrawals.sol';

contract WildcatMarket is
  WildcatMarketBase,
  WildcatMarketConfig,
  WildcatMarketToken,
  WildcatMarketWithdrawals
{
  using MathUtils for uint256;
  using SafeCastLib for uint256;
  using SafeTransferLib for address;

  function updateState() external nonReentrant {
    VaultState memory state = _getUpdatedState();
    _writeState(state);
  }

  function depositUpTo(
    uint256 amount
  ) public virtual nonReentrant returns (uint256 /* actualAmount */) {
    // Get current state
    VaultState memory state = _getUpdatedState();

    if (state.isClosed) {
      revert DepositToClosedVault();
    }

    // Reduce amount if it would exceed totalSupply
    amount = MathUtils.min(amount, state.maximumDeposit());

    // Scale the mint amount
    uint104 scaledAmount = state.scaleAmount(amount).toUint104();
    if (scaledAmount == 0) revert NullMintAmount();

    // Transfer deposit from caller
    asset.safeTransferFrom(msg.sender, address(this), amount);

    // Cache account data and revert if not authorized to deposit.
    Account memory account = _getAccountWithRole(msg.sender, AuthRole.DepositAndWithdraw);
    account.scaledBalance += scaledAmount;
    _accounts[msg.sender] = account;

    emit Transfer(address(0), msg.sender, amount);
    emit Deposit(msg.sender, amount, scaledAmount);

    // Increase supply
    state.scaledTotalSupply += scaledAmount;

    // Update stored state
    _writeState(state);

    return amount;
  }

  function deposit(uint256 amount) external virtual {
    uint256 actualAmount = depositUpTo(amount);
    if (amount != actualAmount) {
      revert MaxSupplyExceeded();
    }
  }

  function collectFees() external nonReentrant {
    VaultState memory state = _getUpdatedState();
    if (state.accruedProtocolFees == 0) {
      revert NullFeeAmount();
    }
    uint128 withdrawableFees = state.withdrawableProtocolFees(totalAssets());
    if (withdrawableFees == 0) {
      revert InsufficientCoverageForFeeWithdrawal();
    }
    state.accruedProtocolFees -= withdrawableFees;
    _writeState(state);
    asset.safeTransfer(feeRecipient, withdrawableFees);
    emit FeesCollected(withdrawableFees);
  }

  function borrow(uint256 amount) external onlyBorrower nonReentrant {
    VaultState memory state = _getUpdatedState();
    if (state.isClosed) {
      revert BorrowFromClosedVault();
    }
    uint256 borrowable = state.borrowableAssets(totalAssets());
    if (amount > borrowable) {
      revert BorrowAmountTooHigh();
    }
    _writeState(state);
    asset.safeTransfer(msg.sender, amount);
    emit Borrow(amount);
  }

  /**
   * @dev Sets the vault APR to 0% and marks vault as closed.
   *      Transfers remaining debts from borrower if vault is not fully
   *      collateralized; otherwise, transfers any assets in excess of
   *      debts to the borrower.
   */
  function closeVault() external onlyController nonReentrant {
    VaultState memory state = _getUpdatedState();
    state.annualInterestBips = 0;
    state.isClosed = true;
    state.liquidityCoverageRatio = 0;
    if (_withdrawalData.unpaidBatches.length() > 0) {
      revert CloseVaultWithUnpaidWithdrawals();
    }
    uint256 currentlyHeld = totalAssets();
    uint256 totalDebts = state.totalDebts();
    if (currentlyHeld < totalDebts) {
      // Transfer remaining debts from borrower
      asset.safeTransferFrom(borrower, address(this), totalDebts - currentlyHeld);
    } else {
      // Transfer excess assets to borrower
      asset.safeTransfer(borrower, currentlyHeld - totalDebts);
    }
    _writeState(state);
    emit VaultClosed(block.timestamp);
  }
}
