// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../interfaces/IERC20.sol';
import '../libraries/FeeMath.sol';
import '../libraries/Withdrawal.sol';
import 'solady/utils/SafeTransferLib.sol';
import { queryName, querySymbol } from '../libraries/StringQuery.sol';
import '../interfaces/IVaultEventsAndErrors.sol';

import '../interfaces/IWildcatVaultController.sol';

import '../interfaces/IWildcatVaultFactory.sol';
import { IERC20Metadata } from '../interfaces/IERC20Metadata.sol';
import '../ReentrancyGuard.sol';
import '../libraries/BoolUtils.sol';

contract WildcatMarketBase is ReentrancyGuard, IVaultEventsAndErrors {
	using WithdrawalLib for VaultState;
	using FeeMath for VaultState;
	using SafeCastLib for uint256;
	using MathUtils for uint256;
	using BoolUtils for bool;

	// ==================================================================== //
	//                       Vault Config (immutable)                       //
	// ==================================================================== //

	/// @dev Account with blacklist control, used for blocking sanctioned addresses.
	address public immutable sentinel;

	/// @dev Account with authority to borrow assets from the vault.
	address public immutable borrower;

	/// @dev Account that receives protocol fees.
	address public immutable feeRecipient;

	/// @dev Protocol fee added to interest paid by borrower.
	uint256 public immutable protocolFeeBips;

	/// @dev Penalty fee added to interest earned by lenders, does not affect protocol fee.
	uint256 public immutable delinquencyFeeBips;

	/// @dev Time after which delinquency incurs penalty fee.
	uint256 public immutable delinquencyGracePeriod;

	/// @dev Address of the Vault Controller.
	address public immutable controller;

	/// @dev Address of the underlying asset.
	address public immutable asset;

	/// @dev Time before withdrawal batches are processed.
	uint256 public immutable withdrawalBatchDuration;

	/// @dev Token decimals (same as underlying asset).
	uint8 public immutable decimals;

	/// @dev Token name (prefixed name of underlying asset).
	string public name;

	/// @dev Token symbol (prefixed symbol of underlying asset).
	string public symbol;

	// ===================================================================== //
	//                             Vault State                               //
	// ===================================================================== //

	VaultState internal _state;

	mapping(address => Account) internal _accounts;

	WithdrawalData internal _withdrawalData;

	// ===================================================================== //
	//                             Constructor                               //
	// ===================================================================== //

	constructor() {
		VaultParameters memory parameters = IWildcatVaultFactory(msg.sender).getVaultParameters();

		if ((parameters.protocolFeeBips > 0).and(parameters.feeRecipient == address(0))) {
			revert FeeSetWithoutRecipient();
		}
		if (parameters.annualInterestBips > BIP) {
			revert InterestRateTooHigh();
		}
		if (parameters.liquidityCoverageRatio > BIP) {
			revert LiquidityCoverageRatioTooHigh();
		}
		if (parameters.protocolFeeBips > BIP) {
			revert InterestFeeTooHigh();
		}
		if (parameters.delinquencyFeeBips > BIP) {
			revert PenaltyFeeTooHigh();
		}

		// Set asset metadata
		asset = parameters.asset;
		name = string.concat(parameters.namePrefix, queryName(parameters.asset));
		symbol = string.concat(parameters.symbolPrefix, querySymbol(parameters.asset));
		decimals = IERC20Metadata(parameters.asset).decimals();

		_state = VaultState({
			maxTotalSupply: parameters.maxTotalSupply,
			accruedProtocolFees: 0,
			reservedAssets: 0,
			scaledTotalSupply: 0,
			scaledPendingWithdrawals: 0,
			pendingWithdrawalExpiry: 0,
			isDelinquent: false,
			timeDelinquent: 0,
			annualInterestBips: parameters.annualInterestBips,
			liquidityCoverageRatio: parameters.liquidityCoverageRatio,
			scaleFactor: uint112(RAY),
			lastInterestAccruedTimestamp: uint32(block.timestamp)
		});

		sentinel = parameters.sentinel;
		borrower = parameters.borrower;
		controller = parameters.controller;
		feeRecipient = parameters.feeRecipient;
		protocolFeeBips = parameters.protocolFeeBips;
		delinquencyFeeBips = parameters.delinquencyFeeBips;
		delinquencyGracePeriod = parameters.delinquencyGracePeriod;
		withdrawalBatchDuration = parameters.withdrawalBatchDuration;
	}

	// ===================================================================== //
	//                              Modifiers                                //
	// ===================================================================== //

	modifier onlyBorrower() {
		if (msg.sender != borrower) revert NotApprovedBorrower();
		_;
	}

	modifier onlyController() {
		if (msg.sender != controller) revert NotController();
		_;
	}

	modifier onlySentinel() {
		if (msg.sender != sentinel) revert BadLaunchCode();
		_;
	}

	// ===================================================================== //
	//                       Internal State Getters                          //
	// ===================================================================== //

	/**
	 * @dev Retrieve an account from storage.
	 *
	 * note: If the account is blacklisted, reverts.
	 */
	function _getAccount(address _account) internal view returns (Account memory account) {
		account = _accounts[_account];
		if (account.approval == AuthRole.Blocked) {
			revert AccountBlacklisted();
		}
	}

	function _checkAccountAuthorization(
		address _account,
		Account memory account,
		AuthRole requiredRole
	) internal {
		if (uint256(account.approval) < uint256(requiredRole)) {
			if (IWildcatVaultController(controller).isAuthorizedLender(_account)) {
				account.approval = AuthRole.DepositAndWithdraw;
				emit AuthorizationStatusUpdated(_account, AuthRole.DepositAndWithdraw);
			} else {
				revert NotApprovedLender();
			}
		}
	}

	/* 	function effectiveAnnualInterestBips() external view returns (uint256) {
    VaultState memory state = _calculateCurrentState();
    return (state.annualInterestBips +
    protocolFeeBips +
    (
    (state.isDelinquent && state.timeDelinquent > delinquencyGracePeriod)
    	? delinquencyFeeBips
    	: 0
    ));
    } */

	// ===================================================================== //
	//                       External State Getters                          //
	// ===================================================================== //

	function coverageLiquidity() public view nonReentrantView returns (uint256) {
		VaultState memory state = _calculateCurrentState();
		return state.liquidityRequired();
	}

	function scaleFactor() external view nonReentrantView returns (uint256) {
		return _calculateCurrentState().scaleFactor;
	}

	/// @dev Total balance in underlying asset
	function totalAssets() public view returns (uint256) {
		return IERC20(asset).balanceOf(address(this));
	}

	/// @dev  Balance in underlying asset which is not owed in fees.
	///       Returns current value after calculating new protocol fees.
	function borrowableAssets() external view nonReentrantView returns (uint256) {
		return totalAssets().satSub(coverageLiquidity());
	}

	function accruedProtocolFees() external view nonReentrantView returns (uint256) {
		return _calculateCurrentState().accruedProtocolFees;
	}

	function previousState() external view returns (VaultState memory) {
		return _state;
	}

	function currentState() external view nonReentrantView returns (VaultState memory state) {
		return _calculateCurrentState();
	}

	// /*//////////////////////////////////////////////////////////////
	//                     Internal State Handlers
	// //////////////////////////////////////////////////////////////*/

	/**
	 * @dev Returns cached VaultState after accruing interest and delinquency / protocol fees
	 *      and processing expired withdrawal batch, if any.
	 *
	 *      Used by functions that make additional changes to `state`.
	 *
	 *      NOTE: Returned `state` does not match `_state` if interest is accrued
	 *            Calling function must update `_state` or revert.
	 *
	 * @return state Vault state after interest is accrued.
	 */
	function _getUpdatedState() internal returns (VaultState memory state) {
		state = _state;
		if (block.timestamp == state.lastInterestAccruedTimestamp) {
			return state;
		}
		// Handle expired withdrawal batch
		if (
			(block.timestamp >= state.pendingWithdrawalExpiry).and(state.pendingWithdrawalExpiry != 0)
		) {
			uint256 expiry = state.pendingWithdrawalExpiry;
			(uint256 baseInterestRay, uint256 delinquencyFeeRay, uint256 protocolFee) = state
				.updateScaleFactorAndFees(
					protocolFeeBips,
					delinquencyFeeBips,
					delinquencyGracePeriod,
					expiry
				);
			emit ScaleFactorUpdated(state.scaleFactor, baseInterestRay, delinquencyFeeRay, protocolFee);
			_processExpiredWithdrawalBatch(state);
		}
		{
			(uint256 baseInterestRay, uint256 delinquencyFeeRay, uint256 protocolFee) = state
				.updateScaleFactorAndFees(
					protocolFeeBips,
					delinquencyFeeBips,
					delinquencyGracePeriod,
					block.timestamp
				);
			emit ScaleFactorUpdated(state.scaleFactor, baseInterestRay, delinquencyFeeRay, protocolFee);
		}
	}

	function _calculateCurrentState() internal view returns (VaultState memory state) {
		state = _state;
		if (block.timestamp == state.lastInterestAccruedTimestamp) {
			return state;
		}
		// Handle expired withdrawal batch
		if (
			(state.pendingWithdrawalExpiry != 0).and(block.timestamp >= state.pendingWithdrawalExpiry)
		) {
			uint256 expiry = state.pendingWithdrawalExpiry;
			state.updateScaleFactorAndFees(
				protocolFeeBips,
				delinquencyFeeBips,
				delinquencyGracePeriod,
				expiry
			);
			// @todo: fix this (make view version of processExpiredBatch)
			// WithdrawalBatch memory batch = state.processExpiredBatch(state.liquidAssets(totalAssets()));
		}
		state.updateScaleFactorAndFees(
			protocolFeeBips,
			delinquencyFeeBips,
			delinquencyGracePeriod,
			block.timestamp
		);
	}

	/**
	 * @dev Writes the cached VaultState to storage and emits an event.
	 *      Used at the end of all functions which modify `state`.
	 */
	function _writeState(VaultState memory state) internal {
		bool isDelinquent = state.liquidityRequired() > totalAssets();
		state.isDelinquent = isDelinquent;
		_state = state;
		emit StateUpdated(state.scaleFactor, isDelinquent);
	}

	/**
	 * @dev When a withdrawal batch expires, the vault will checkpoint the scale factor
	 *      as of the time of expiry and retrieve the current liquid assets in the vault
	 * (assets which are not already owed to protocol fees or prior withdrawal batches).
	 */
	function _processExpiredWithdrawalBatch(VaultState memory state) internal {
		WithdrawalBatch storage batch = _withdrawalData.batches[state.pendingWithdrawalExpiry];

		// Get the liquidity which is not already reserved for prior withdrawal batches
		// or owed to protocol fees.
		uint256 availableLiquidity = batch.availableLiquidityForBatch(state, totalAssets());

		uint104 scaledTotalAmount = batch.scaledTotalAmount;

		uint128 normalizedOwedAmount = state.normalizeAmount(scaledTotalAmount).toUint128();

		(uint104 scaledAmountBurned, uint128 normalizedAmountPaid) = (availableLiquidity >=
			normalizedOwedAmount)
			? (scaledTotalAmount, normalizedOwedAmount)
			: (state.scaleAmount(availableLiquidity).toUint104(), availableLiquidity.toUint128());

		batch.scaledAmountBurned = scaledAmountBurned;
		batch.normalizedAmountPaid = normalizedAmountPaid;

		emit WithdrawalBatchExpired(
			state.pendingWithdrawalExpiry,
			scaledTotalAmount,
			scaledAmountBurned,
			normalizedAmountPaid
		);

		if (scaledAmountBurned < scaledTotalAmount) {
			_withdrawalData.unpaidBatches.push(state.pendingWithdrawalExpiry);
		} else {
			emit WithdrawalBatchClosed(state.pendingWithdrawalExpiry);
		}

		state.pendingWithdrawalExpiry = 0;
		state.reservedAssets += normalizedAmountPaid;

		if (scaledAmountBurned > 0) {
			// Emit transfer for external trackers to indicate burn
			emit Transfer(address(this), address(0), normalizedAmountPaid);
			state.scaledPendingWithdrawals -= scaledAmountBurned;
			state.scaledTotalSupply -= scaledAmountBurned;
		}
	}
}
