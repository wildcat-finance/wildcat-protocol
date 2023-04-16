// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './interfaces/IERC20.sol';
import './libraries/FeeMath.sol';
import 'solady/utils/SafeTransferLib.sol';
import { queryName, querySymbol } from './libraries/StringQuery.sol';
import './interfaces/IVaultErrors.sol';

import './interfaces/IWildcatVaultFactory.sol';
import { IERC20Metadata } from './interfaces/IERC20Metadata.sol';
import './ReentrancyGuard.sol';

contract DebtTokenBase is ReentrancyGuard, IVaultErrors {
	using SafeTransferLib for address;
	using MathUtils for uint256;
	using FeeMath for VaultState;
	using WadRayMath for uint256;
	using SafeCastLib for uint256;

	/*//////////////////////////////////////////////////////////////
                      Storage and Constants
  //////////////////////////////////////////////////////////////*/

	address public immutable borrower;
	address public immutable feeRecipient;

	VaultState internal _state;

	uint256 public lastAccruedProtocolFees;

	mapping(address => uint256) public scaledBalanceOf;

	mapping(address => mapping(address => uint256)) public allowance;

	uint256 public immutable interestFeeBips;

	uint256 public immutable penaltyFeeBips;

	uint256 public immutable gracePeriod;

	address public immutable controller;

	address public immutable asset;

	uint8 public immutable decimals;

	string public name;

	string public symbol;

	/*//////////////////////////////////////////////////////////////
                            Modifiers
  //////////////////////////////////////////////////////////////*/

	modifier onlyBorrower() {
		if (msg.sender != borrower) revert NotBorrower();
		_;
	}

	modifier onlyController() {
		if (msg.sender != controller) revert NotController();
		_;
	}

	constructor() {
		VaultParameters memory parameters = IWildcatVaultFactory(msg.sender).getVaultParameters();
		borrower = parameters.borrower;
		feeRecipient = parameters.feeRecipient;

		// Set asset metadata
		asset = parameters.asset;
		name = string.concat(parameters.namePrefix, queryName(parameters.asset));
		symbol = string.concat(parameters.symbolPrefix, queryName(parameters.asset));
		decimals = IERC20Metadata(parameters.asset).decimals();

		_state = VaultState({
			maxTotalSupply: parameters.maxTotalSupply.safeCastTo128(),
			scaledTotalSupply: 0,
			isDelinquent: false,
			timeDelinquent: 0,
			liquidityCoverageRatio: parameters.liquidityCoverageRatio.safeCastTo16(),
			annualInterestBips: parameters.annualInterestBips.safeCastTo16(),
			scaleFactor: uint112(RAY),
			lastInterestAccruedTimestamp: uint32(block.timestamp)
		});

		if (parameters.annualInterestBips > BIP) {
			revert InterestRateTooHigh();
		}
		if (parameters.liquidityCoverageRatio > BIP) {
			revert LiquidityCoverageRatioTooHigh();
		}
		if (parameters.interestFeeBips > BIP) {
			revert InterestFeeTooHigh();
		}
		if (parameters.penaltyFeeBips > BIP) {
			revert PenaltyFeeTooHigh();
		}

		interestFeeBips = parameters.interestFeeBips;
		controller = parameters.controller;
		penaltyFeeBips = parameters.penaltyFeeBips;
		gracePeriod = parameters.gracePeriod;
	}

	/*//////////////////////////////////////////////////////////////
                        Management Actions
  //////////////////////////////////////////////////////////////*/

	/**
	 * @dev Sets the maximum total supply - this only limits deposits and
	 * does not affect interest accrual.
	 */
	function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyController nonReentrant {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		state.setMaxTotalSupply(_maxTotalSupply);
		_writeState(state);
		emit MaxSupplyUpdated(_maxTotalSupply);
	}

	function setAnnualInterestBips(uint256 _annualInterestBips) public onlyController nonReentrant {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		state.setAnnualInterestBips(_annualInterestBips);
		_writeState(state);
	}

	function setLiquidityCoverageRatio(
		uint256 _liquidityCoverageRatio
	) public onlyController nonReentrant {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		state.setLiquidityCoverageRatio(_liquidityCoverageRatio);
		_writeState(state);
	}

	/*//////////////////////////////////////////////////////////////
                            ERC20 Actions                        
  //////////////////////////////////////////////////////////////*/

	function approve(address spender, uint256 amount) external virtual returns (bool) {
		_approve(msg.sender, spender, amount);

		return true;
	}

	function transferFrom(
		address from,
		address to,
		uint256 amount
	) external virtual nonReentrant returns (bool) {
		uint256 allowed = allowance[from][msg.sender];

		// Saves gas for unlimited approvals.
		if (allowed != type(uint256).max) {
			uint256 newAllowance = allowed - amount;
			_approve(from, msg.sender, newAllowance);
		}

		_transfer(from, to, amount);

		return true;
	}

	function depositUpTo(
		uint256 amount,
		address to
	) public virtual nonReentrant returns (uint256 /* actualAmount */) {
		// Get current state
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();

		// Reduce amount if it would exceed totalSupply
		amount = MathUtils.min(amount, state.getMaximumDeposit());

		// Scale the actual mint amount
		uint256 scaledAmount = state.scaleAmount(amount);

		// Transfer deposit from caller
		asset.safeTransferFrom(msg.sender, address(this), amount);

		// Increase user's balance
		scaledBalanceOf[to] += scaledAmount;
		emit Transfer(address(0), to, scaledAmount);
		emit Deposit(msg.sender, amount, scaledAmount);

		// Increase supply
		state.increaseScaledTotalSupply(scaledAmount);

		_writeState(state);
	}

	function _approve(address approver, address spender, uint256 amount) internal virtual {
		allowance[approver][spender] = amount;
		emit Approval(approver, spender, amount);
	}

	function _transfer(address from, address to, uint256 amount) internal virtual {
		(VaultState memory state,) = _getCurrentStateAndAccrueFees();
		uint256 scaledAmount = state.scaleAmount(amount);
		scaledBalanceOf[from] -= scaledAmount;
		unchecked {
			scaledBalanceOf[to] += scaledAmount;
		}
		emit Transfer(from, to, amount);
	}

	/*//////////////////////////////////////////////////////////////
                        External Getters
  //////////////////////////////////////////////////////////////*/

	/// @notice Returns the normalized balance of `account` with interest.
	function balanceOf(address account) public view virtual nonReentrantView returns (uint256) {
		// Get current state
		(VaultState memory state, ) = _getCurrentState();
		return state.normalizeAmount(scaledBalanceOf[account]);
	}

	/// @notice Returns the normalized total supply with interest.
	function totalSupply() external view virtual nonReentrantView returns (uint256) {
		(VaultState memory state, ) = _getCurrentState();
		return state.getTotalSupply();
	}

	function maxTotalSupply() external view returns (uint256) {
		return _state.maxTotalSupply;
	}

	function annualInterestBips() external view returns (uint256) {
		return _state.annualInterestBips;
	}

  function liquidityCoverageRatio() external view returns (uint256) {
    return _state.liquidityCoverageRatio;
  }

	function scaleFactor() external view nonReentrantView returns (uint256) {
		(VaultState memory state, ) = _getCurrentState();
		return state.scaleFactor;
	}

	/// @dev Total balance in underlying asset
	function totalAssets() public view nonReentrantView returns (uint256) {
		return IERC20(asset).balanceOf(address(this));
	}

	/// @dev  Balance in underlying asset which is not owed in fees.
	///       Returns current value after calculating new protocol fees.
	function borrowableAssets() public view nonReentrantView returns (uint256) {
		(, uint256 _accruedProtocolFees) = _getCurrentState();
		return totalAssets().satSub(_accruedProtocolFees);
	}

	function accruedProtocolFees()
		external
		view
		nonReentrantView
		returns (uint256 _accruedProtocolFees)
	{
		(, _accruedProtocolFees) = _getCurrentState();
	}

	function getState() external view returns (VaultState memory) {
		(VaultState memory state, ) = _getCurrentState();
		return state;
	}

	/*//////////////////////////////////////////////////////////////
                      Internal State Handlers
  //////////////////////////////////////////////////////////////*/

	/**
	 * @dev Returns ScaleParameters with interest since last update accrued to the cache
	 *      and updates storage with accrued protocol fees.
	 *
	 *      Used by functions that make additional changes to `state`.
	 *
	 *      NOTE: Returned `state` does not match `_state` if interest is accrued
	 *            Calling function must update `_state` or revert.
	 *
	 * @return state Vault state after interest is accrued.
	 */
	function _getCurrentStateAndAccrueFees() internal returns (VaultState memory, bool) {
		VaultState memory state = _state;
		(uint256 feesAccrued, bool didUpdate) = state.calculateInterestAndFees(
			interestFeeBips,
			penaltyFeeBips,
			gracePeriod
		);
		if (didUpdate) {
			lastAccruedProtocolFees += feesAccrued;
		}
		return (state, didUpdate);
	}

	function _getCurrentState()
		internal
		view
		returns (VaultState memory state, uint256 _accruedProtocolFees)
	{
		state = _state;
		(uint256 feesAccrued, ) = state.calculateInterestAndFees(
			interestFeeBips,
			penaltyFeeBips,
			gracePeriod
		);
		_accruedProtocolFees = lastAccruedProtocolFees + feesAccrued;
	}

	function _writeState(VaultState memory state) internal {
		state.isDelinquent = state.liquidityRequired() > totalAssets();
		_state = state;
	}
}
