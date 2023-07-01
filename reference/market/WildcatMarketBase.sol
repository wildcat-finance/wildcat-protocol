// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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

contract WildcatMarketBase is ReentrancyGuard, IVaultEventsAndErrors {
	using WithdrawalLib for VaultState;
	using FeeMath for VaultState;
	using SafeCastLib for uint256;
	using MathUtils for uint256;

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

	mapping(uint256 => WithdrawalBatch) internal _withdrawalBatches;

	mapping(uint256 => mapping(address => AccountWithdrawalStatus))
		internal _accountWithdrawalStatuses;

	// ===================================================================== //
	//                             Constructor                               //
	// ===================================================================== //

	constructor() {
		VaultParameters memory parameters = IWildcatVaultFactory(msg.sender).getVaultParameters();

		if (parameters.protocolFeeBips > 0 && parameters.feeRecipient == address(0)) {
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
			maxTotalSupply: parameters.maxTotalSupply.safeCastTo128(),
			accruedProtocolFees: 0,
			reservedAssets: 0,
			scaledTotalSupply: 0,
			scaledPendingWithdrawals: 0,
			pendingWithdrawalExpiry: 0,
			isDelinquent: false,
			timeDelinquent: 0,
			annualInterestBips: parameters.annualInterestBips.safeCastTo16(),
			liquidityCoverageRatio: parameters.liquidityCoverageRatio.safeCastTo16(),
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

	// ===================================================================== //
	//                      External Config Getters                          //
	// ===================================================================== //

	/**
	 * @dev Returns the maximum amount of underlying asset that can
	 *      currently be deposited to the market.
	 */
	function maximumDeposit() external view returns (uint256) {
		return _calculateCurrentState().getMaximumDeposit();
	}

	/**
	 * @dev Returns the maximum supply the market can reach via
	 *      deposits (does not apply to interest accrual).
	 */
	function maxTotalSupply() external view returns (uint256) {
		return _state.maxTotalSupply;
	}

	/**
	 * @dev Returns the annual interest rate earned by lenders
	 *      in bips.
	 */
	function annualInterestBips() external view returns (uint256) {
		return _state.annualInterestBips;
	}

	function liquidityCoverageRatio() external view returns (uint256) {
		return _state.liquidityCoverageRatio;
	}

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
	function borrowableAssets() public view nonReentrantView returns (uint256) {
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
	function _getCurrentStateAndAccrueFees() internal returns (VaultState memory state) {
		state = _state;
		if (block.timestamp == state.lastInterestAccruedTimestamp) {
			return state;
		}
		// Handle expired withdrawal batch
		if (block.timestamp >= state.pendingWithdrawalExpiry) {
			uint256 expiry = state.pendingWithdrawalExpiry;
			(
				uint256 baseInterestRay,
				uint256 delinquencyFeeRay,
				uint256 protocolFee
			) = _updateScaleFactorAndFees(state, expiry);
			emit ScaleFactorUpdated(state.scaleFactor, baseInterestRay, delinquencyFeeRay, protocolFee);
			WithdrawalBatch memory batch = state.processExpiredBatch(
				_withdrawalBatches,
				state.liquidAssets(totalAssets())
			);
			emit WithdrawalBatchExpired(
				expiry,
				batch.scaledTotalAmount,
				batch.scaledPaidAmount,
				batch.normalizedPaidAmount
			);
			if (state.scaledPendingWithdrawals > 0) {
				emit WithdrawalBatchCreated(state.pendingWithdrawalExpiry, state.scaledPendingWithdrawals);
			}
		}
		{
			(
				uint256 baseInterestRay,
				uint256 delinquencyFeeRay,
				uint256 protocolFee
			) = _updateScaleFactorAndFees(state, block.timestamp);
			emit ScaleFactorUpdated(state.scaleFactor, baseInterestRay, delinquencyFeeRay, protocolFee);
		}
	}

	function _calculateCurrentState() internal view returns (VaultState memory state) {
		state = _state;
		if (block.timestamp == state.lastInterestAccruedTimestamp) {
			return state;
		}
		// Handle expired withdrawal batch
		if (block.timestamp >= state.pendingWithdrawalExpiry) {
			uint256 expiry = state.pendingWithdrawalExpiry;
			_updateScaleFactorAndFees(state, expiry);
      // @todo: fix this (make view version of processExpiredBatch)
			// WithdrawalBatch memory batch = state.processExpiredBatch(state.liquidAssets(totalAssets()));
		}
		_updateScaleFactorAndFees(state, block.timestamp);
	}

	function _writeState(VaultState memory state) internal {
		bool isDelinquent = state.liquidityRequired() > totalAssets();
		state.isDelinquent = isDelinquent;
		_state = state;
		emit StateUpdated(state.scaleFactor, isDelinquent);
	}

	/**
	 * @dev Calculates interest and delinquency/protocol fees accrued since last state update
	 *      and applies it to cached state, returning the rates for base interest and delinquency
	 *      fees and the normalized amount of protocol fees accrued.
	 *
	 * @param state Vault scale parameters
	 * @param timestamp Time to calculate interest and fees accrued until
	 * @return baseInterestRay Interest accrued to lenders (ray)
	 * @return delinquencyFeeRay Penalty fee incurred by borrower for delinquency (ray).
	 * @return protocolFee Protocol fee charged on interest (normalized token amount).
	 */
	function _updateScaleFactorAndFees(
		VaultState memory state,
		uint256 timestamp
	)
		internal
		view
		returns (uint256 baseInterestRay, uint256 delinquencyFeeRay, uint256 protocolFee)
	{
		baseInterestRay = FeeMath.calculateLinearInterestFromBips(
			state.annualInterestBips,
			timestamp - state.lastInterestAccruedTimestamp
		);

		if (protocolFeeBips > 0) {
			protocolFee = state.applyProtocolFee(baseInterestRay, protocolFeeBips);
		}

		if (delinquencyFeeBips > 0) {
			delinquencyFeeRay = state.updateDelinquency(
				timestamp,
				delinquencyFeeBips,
				delinquencyGracePeriod
			);
		}

		// Calculate new scaleFactor
		uint256 prevScaleFactor = state.scaleFactor;
		uint256 scaleFactorDelta = prevScaleFactor.rayMul(baseInterestRay + delinquencyFeeRay);

		state.scaleFactor = (prevScaleFactor + scaleFactorDelta).safeCastTo112();
		state.lastInterestAccruedTimestamp = uint32(timestamp);
	}
}
