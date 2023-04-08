// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './interfaces/IERC20.sol';
import './libraries/FeeMath.sol';
import './libraries/SafeTransferLib.sol';
import { queryName, querySymbol } from './libraries/StringQuery.sol';
import './libraries/Math.sol';
import './interfaces/IWildcatPermissions.sol';
import './interfaces/IVaultErrors.sol';

import './interfaces/IWildcatVaultFactory.sol';
import { IERC20Metadata } from './interfaces/IERC20Metadata.sol';

contract UncollateralizedDebtToken is IVaultErrors {
	using SafeTransferLib for address;
	using MathUtils for uint256;
	using FeeMath for VaultState;
	using WadRayMath for uint256;
	using SafeCastLib for uint256;

	/*//////////////////////////////////////////////////////////////
                      Storage and Constants
  //////////////////////////////////////////////////////////////*/

	address public owner;

	VaultState internal _state;

	uint256 public accruedProtocolFees;

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

	modifier onlyOwner() {
		if (msg.sender != owner) revert NotOwner();
		_;
	}

	modifier onlyController() {
		_;
	}

	constructor() {
		VaultParameters memory parameters = IWildcatVaultFactory(msg.sender).getVaultParameters();
		owner = parameters.owner;

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

	function _liquidityCoverageRatio() internal {}

	/*//////////////////////////////////////////////////////////////
                        Management Actions
  //////////////////////////////////////////////////////////////*/

	/**
	 * @dev Sets the maximum total supply - this only limits deposits and
	 * does not affect interest accrual.
	 */
	function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyOwner {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		state.setMaxTotalSupply(_maxTotalSupply);
		// Store new vault supply with updated maxTotalSupply
		_state = state;
		emit MaxSupplyUpdated(_maxTotalSupply);
	}

	function setAnnualInterestBips(uint16 _annualInterestBips) public onlyOwner {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		state.annualInterestBips = _annualInterestBips;
		_state = state;
	}

	/*//////////////////////////////////////////////////////////////
                            Mint & Burn
//////////////////////////////////////////////////////////////*/

	function depositUpTo(uint256 amount, address to) public virtual returns (uint256 actualAmount) {
		// Get current state
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();

		// Reduce amount if it would exceed totalSupply
		actualAmount = MathUtils.min(amount, state.getMaximumDeposit());

		// Scale the actual mint amount
		uint256 scaledAmount = actualAmount.rayDiv(state.scaleFactor);

		// Transfer deposit from caller
		asset.safeTransferFrom(msg.sender, address(this), amount);

		// Increase user's balance
		scaledBalanceOf[to] += scaledAmount;
		emit Transfer(address(0), to, actualAmount);

		// Increase supply
		state.scaledTotalSupply = (uint256(state.scaledTotalSupply) + scaledAmount).safeCastTo128();

		_state = state;
	}

	function deposit(uint256 amount, address to) external virtual {
		if (depositUpTo(amount, to) != amount) {
			revert MaxSupplyExceeded();
		}
	}

	function withdraw(uint256 amount, address to) external virtual {
		// Get current state
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		uint256 scaledAmount = state.scaleAmount(amount);

		// Reduce caller's balance
		scaledBalanceOf[msg.sender] -= scaledAmount;
		emit Transfer(msg.sender, address(0), amount);

		// Reduce supply
		state.scaledTotalSupply = (uint256(state.scaledTotalSupply) - scaledAmount).safeCastTo128();

		// Transfer withdrawn assets to `user`
		asset.safeTransfer(to, amount);

		_state = state;
	}

	/*//////////////////////////////////////////////////////////////
                        External Getters
//////////////////////////////////////////////////////////////*/

	/**
	 * @notice Returns the normalized balance of `account` with interest.
	 */
	function balanceOf(address account) public view virtual returns (uint256) {
		// Get current state
		VaultState memory state = _getCurrentState();
		return state.normalizeAmount(scaledBalanceOf[account]);
	}

	/**
	 * @notice Returns the normalized total supply with interest.
	 */
	function totalSupply() public view virtual returns (uint256) {
		VaultState memory state = _getCurrentState();
		return state.getTotalSupply();
	}

	function currentAnnualInterestBips() public view returns (uint256) {
		return _state.annualInterestBips;
	}

	function currentScaleFactor() public view returns (uint256) {
		VaultState memory state = _getCurrentState();
		return state.scaleFactor;
	}

	function maxTotalSupply() public view virtual returns (uint256) {
		return _state.maxTotalSupply;
	}

	/**
	 * @dev Total balance in underlying asset
	 */
	function totalAssets() public view returns (uint256) {
		return IERC20(asset).balanceOf(address(this));
	}

	/**
	 * @dev Balance in underlying asset which is not reserved for fees.
	 */
	function availableAssets() public view returns (uint256) {
		return totalAssets().satSub(accruedProtocolFees);
	}

	/*//////////////////////////////////////////////////////////////
                      Internal State Handlers
//////////////////////////////////////////////////////////////*/
	/**
	 * @dev Returns ScaleParameters with interest since last update accrued to the cache
	 *      and updates storage with accrued protocol fees.
	 *      This is used by functions that make additional changes to the vault state.
	 *
	 * @return state Vault state after interest is accrued - does not match stored object.
	 */
	function _getCurrentStateAndAccrueFees() internal returns (VaultState memory, bool) {
		VaultState memory state = _state;
		(uint256 feesAccrued, bool didUpdate) = state.calculateInterestAndFees(
			interestFeeBips,
			penaltyFeeBips,
			gracePeriod
		);
		if (didUpdate) {
			// If pool has insufficient assets to transfer fees, treat fees as
			// deposited assets to mint shares for fee recipient. This results
			// in interest being charged on fees when the borrower does not
			// maintain collateralization requirements.
			if (availableAssets() < feesAccrued) {
				uint256 scaledFee = feesAccrued.rayDiv(state.scaleFactor);
				state.scaledTotalSupply = (uint256(state.scaledTotalSupply) + scaledFee).safeCastTo128();
				scaledBalanceOf[controller] += scaledFee;
				emit Transfer(address(0), controller, scaledFee);
			} else {
				accruedProtocolFees += feesAccrued;
			}
		}
		return (state, didUpdate);
	}

	/**
	 * @dev   Returns ScaleParameters with interest since last update accrued
	 *        to both the cached and stored vault states, and updates storage
	 *        with accrued protocol fees.
	 *
	 * @dev   Used in functions that don't make additional changes to the
	 *        vault state.
	 * @return state Vault state after interest is accrued - matches stored object.
	 */
	function _getUpdatedStateAndAccrueFees() internal returns (VaultState memory) {
		(VaultState memory state, bool didUpdate) = _getCurrentStateAndAccrueFees();
		if (didUpdate) {
			_state = state;
		}
		return state;
	}

	function _getCurrentState() internal view returns (VaultState memory state) {
		state = _state;
		state.calculateInterestAndFees(interestFeeBips, penaltyFeeBips, gracePeriod);
	}

	/*//////////////////////////////////////////////////////////////
                            ERC20 Actions                        
//////////////////////////////////////////////////////////////*/

	function approve(address spender, uint256 amount) external virtual returns (bool) {
		_approve(msg.sender, spender, amount);

		return true;
	}

	function transferFrom(
		address sender,
		address recipient,
		uint256 amount
	) external virtual returns (bool) {
		uint256 allowed = allowance[sender][msg.sender];

		// Saves gas for unlimited approvals.
		if (allowed != type(uint256).max) {
			uint256 newAllowance = allowed - amount;
			_approve(sender, msg.sender, newAllowance);
		}

		_transfer(sender, recipient, amount);

		return true;
	}

	function transfer(address recipient, uint256 amount) external virtual returns (bool) {
		_transfer(msg.sender, recipient, amount);
		return true;
	}

	function _approve(address approver, address spender, uint256 amount) internal virtual {
		allowance[approver][spender] = amount;
		emit Approval(approver, spender, amount);
	}

	function _transfer(address from, address to, uint256 amount) internal virtual {
		VaultState memory state = _getUpdatedStateAndAccrueFees();
		uint256 scaledAmount = state.scaleAmount(amount);
		scaledBalanceOf[from] -= scaledAmount;
		unchecked {
			scaledBalanceOf[to] += scaledAmount;
		}
		emit Transfer(from, to, amount);
	}
}
