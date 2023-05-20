// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './interfaces/IERC20.sol';
import './libraries/FeeMath.sol';
import 'solady/utils/SafeTransferLib.sol';
import { queryName, querySymbol } from './libraries/StringQuery.sol';
import './interfaces/IVaultEventsAndErrors.sol';

import './interfaces/IWildcatVaultFactory.sol';
import { IERC20Metadata } from './interfaces/IERC20Metadata.sol';
import './ReentrancyGuard.sol';
import './WildcatVaultController.sol';

contract DebtTokenBase is ReentrancyGuard, IVaultEventsAndErrors {
	using SafeTransferLib for address;
	using MathUtils for uint256;
	using FeeMath for VaultState;
	using WadRayMath for uint256;
	using SafeCastLib for uint256;

	/*//////////////////////////////////////////////////////////////
                      Storage and Constants
  //////////////////////////////////////////////////////////////*/

	address public immutable sentinel;
	address public immutable borrower;
	address public immutable feeRecipient;

	VaultState internal _state;

	uint256 public lastAccruedProtocolFees;

	mapping(address => Account) internal _accounts;

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
		if (msg.sender != borrower) revert NotApprovedBorrower();
		_;
	}

	modifier onlyController() {
		if (msg.sender != controller) revert NotController();
		_;
	}

	/**
	 * @dev Retrieve an account from storage or create a new one if it doesn't exist
	 *      Also updates the account's last recorded scaleFactor and emits a Transfer
	 *     event if it has accrued interest.
   *
   * note: If the account is blacklisted, reverts.
	 */
	function _getUpdatedAccount(
		VaultState memory state,
		address _account
	) internal returns (Account memory account) {
		account = _accounts[_account];
    if (account.approval == AuthRole.Blocked) {
      revert AccountBlacklisted();
    }
		// Track the growth from interest in the normalized balance
		uint256 diff = account.getNormalizedBalanceGrowth(state);
		account.scaleFactor = state.scaleFactor;
		if (diff > 0) {
			emit Transfer(address(0), _account, diff);
		}
	}

	function _checkAccountAuthorization(address _account, Account memory account, AuthRole requiredRole) internal {
		if (uint256(account.approval) < uint256(requiredRole)) {
			if (WildcatVaultController(controller).isAuthorizedLender(_account)) {
				account.approval = AuthRole.DepositAndWithdraw;
				emit AuthorizationStatusUpdated(_account, AuthRole.DepositAndWithdraw);
			} else {
        revert NotApprovedLender();
      }
		}
	}

	/**
	 * Revoke an account's authorization to deposit assets.
	 */
	function revokeAccountAuthorization(address _account) external onlyController nonReentrant {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		Account memory account = _getUpdatedAccount(state, _account);
		account.approval = AuthRole.WithdrawOnly;
		_accounts[_account] = account;
    _writeState(state);
		emit AuthorizationStatusUpdated(_account, AuthRole.WithdrawOnly);
	}

	/**
	 * Restore an account's authorization to deposit assets.
   * Can not be used to restore a blacklisted account's status.
	 */
	function grantAccountAuthorization(address _account) external onlyController nonReentrant {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		Account memory account = _getUpdatedAccount(state, _account);
		account.approval = AuthRole.DepositAndWithdraw;
		_accounts[_account] = account;
    _writeState(state);
		emit AuthorizationStatusUpdated(_account, AuthRole.DepositAndWithdraw);
	}
  /// @dev Block an account from interacting with the market and
  ///      delete its balance.
  //          *  |\**/|  *          *                                *           
  //          *  \ == /  *          *                                *           
  //          *   | b|   *          *                                *           
  //          *   | y|   *          *                                *           
  //          *   \ e/   *          *                                *           
  //          *    \/    *          *                                *           
  //          *          *          *                                *           
  //          *          *          *                                *           
  //          *          *  |\**/|  *                                *           
  //          *          *  \ == /  *         _.-^^---....,,--       *           
  //          *          *   | b|   *    _--                  --_    *           
  //          *          *   | y|   *   <                        >)  *           
  //          *          *   \ e/   *   |         O-FAC!          |  *           
  //          *          *    \/    *    \._                   _./   *           
  //          *          *          *       ```--. . , ; .--'''      *           
  //          *          *          *   💸        | |   |            *           
  //          *          *          *          .-=||  | |=-.    💸   *           
  //  💰🤑💰  *    😅    *    😐    *    💸    `-=#$%&%$#=-'         *           
  //   \|/    *   /|\    *   /|\    *  🌪         | ;  :|    🌪      *           
  //   /\     * 💰/\ 💰  * 💰/\ 💰  *    _____.,-#%&$@%#&#~,._____   *           
	function nukeFromOrbit(address _account) external {
		if (msg.sender != sentinel) {
			revert BadLaunchCode();
		}
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		Account memory account = _getUpdatedAccount(state, _account);
		uint256 scaledBalance = account.scaledBalance;
		uint256 amount = state.normalizeAmount(scaledBalance);
		_accounts[_account] = Account({ scaledBalance: 0, scaleFactor: 0, approval: AuthRole.Blocked });
		if (scaledBalance > 0) {
			state.decreaseScaledTotalSupply(scaledBalance);
		}
		if (amount > 0) {
			emit Transfer(_account, address(0), amount);
		}
		_writeState(state);
		emit AuthorizationStatusUpdated(_account, AuthRole.Blocked);
	}

	constructor() {
		VaultParameters memory parameters = IWildcatVaultFactory(msg.sender).getVaultParameters();
		sentinel = parameters.sentinel;
		borrower = parameters.borrower;
		feeRecipient = parameters.feeRecipient;

		if (parameters.interestFeeBips > 0 && feeRecipient == address(0)) {
			revert FeeSetWithoutRecipient();
		}
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

		// Set asset metadata
		asset = parameters.asset;
		name = string.concat(parameters.namePrefix, queryName(parameters.asset));
		symbol = string.concat(parameters.symbolPrefix, querySymbol(parameters.asset));
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
		emit AnnualInterestBipsUpdated(_annualInterestBips);
	}

	function setLiquidityCoverageRatio(
		uint256 _liquidityCoverageRatio
	) public onlyController nonReentrant {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		state.setLiquidityCoverageRatio(_liquidityCoverageRatio);
		_writeState(state);
		emit LiquidityCoverageRatioUpdated(_liquidityCoverageRatio);
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
		uint256 amount
	) public virtual nonReentrant returns (uint256 /* actualAmount */) {
		// Get current state
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();

		// Reduce amount if it would exceed totalSupply
		amount = MathUtils.min(amount, state.getMaximumDeposit());

		// Scale the actual mint amount
		uint256 scaledAmount = state.scaleAmount(amount);

		// Transfer deposit from caller
		asset.safeTransferFrom(msg.sender, address(this), amount);

		// Update account
		Account memory account = _getUpdatedAccount(state, msg.sender);
    _checkAccountAuthorization(msg.sender, account, AuthRole.DepositAndWithdraw);

		account.increaseScaledBalance(scaledAmount);
		_accounts[msg.sender] = account;

		emit Transfer(address(0), msg.sender, amount);
		emit Deposit(msg.sender, amount, scaledAmount);

		// Increase supply
		state.increaseScaledTotalSupply(scaledAmount);

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

	function withdraw(uint256 amount) external virtual nonReentrant {
		// Get current state
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();

		// Scale the actual mint amount
		uint256 scaledAmount = state.scaleAmount(amount);

		// Update account
		Account memory account = _getUpdatedAccount(state, msg.sender);
    _checkAccountAuthorization(msg.sender, account, AuthRole.WithdrawOnly);

		account.decreaseScaledBalance(scaledAmount);
		_accounts[msg.sender] = account;

		// Reduce caller's balance
		emit Transfer(msg.sender, address(0), amount);
		emit Withdrawal(msg.sender, amount, scaledAmount);

		// Reduce supply
		state.decreaseScaledTotalSupply(scaledAmount);

		// Transfer withdrawn assets to `to`
		asset.safeTransfer(msg.sender, amount);

		// Update stored state
		_writeState(state);
	}

	function _approve(address approver, address spender, uint256 amount) internal virtual {
		allowance[approver][spender] = amount;
		emit Approval(approver, spender, amount);
	}

	function _transfer(address from, address to, uint256 amount) internal virtual {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		uint256 scaledAmount = state.scaleAmount(amount);

		Account memory fromAccount = _getUpdatedAccount(state, from);
		fromAccount.decreaseScaledBalance(scaledAmount);
		_accounts[from] = fromAccount;

		Account memory toAccount = _getUpdatedAccount(state, to);
		toAccount.increaseScaledBalance(scaledAmount);
		_accounts[to] = toAccount;

		emit Transfer(from, to, amount);
	}

	/*//////////////////////////////////////////////////////////////
                        External Getters
  //////////////////////////////////////////////////////////////*/

	/// @notice Returns the normalized balance of `account` with interest.
	function balanceOf(address account) public view virtual nonReentrantView returns (uint256) {
		// Get current state
		(VaultState memory state, ) = _getCurrentState();
		return state.normalizeAmount(_accounts[account].scaledBalance);
	}

	/// @notice Returns the normalized total supply with interest.
	function totalSupply() external view virtual nonReentrantView returns (uint256) {
		(VaultState memory state, ) = _getCurrentState();
		return state.getTotalSupply();
	}

	function maximumDeposit() external view returns (uint256) {
		(VaultState memory state, ) = _getCurrentState();
		return state.getMaximumDeposit();
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
	function totalAssets() public view returns (uint256) {
		return IERC20(asset).balanceOf(address(this));
	}

	function coverageLiquidity() public view nonReentrantView returns (uint256) {
		(VaultState memory state, uint256 _accruedProtocolFees) = _getCurrentState();
		return state.liquidityRequired(_accruedProtocolFees);
	}

	/// @dev  Balance in underlying asset which is not owed in fees.
	///       Returns current value after calculating new protocol fees.
	function borrowableAssets() public view nonReentrantView returns (uint256) {
		return totalAssets().satSub(coverageLiquidity());
	}

	function accruedProtocolFees()
		external
		view
		nonReentrantView
		returns (uint256 _accruedProtocolFees)
	{
		(, _accruedProtocolFees) = _getCurrentState();
	}

	function previousState() external view returns (VaultState memory) {
		return _state;
	}

	function currentState()
		external
		view
		nonReentrantView
		returns (VaultState memory state, uint256 _accruedProtocolFees)
	{
		return _getCurrentState();
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
		bool isDelinquent = state.liquidityRequired(lastAccruedProtocolFees) > totalAssets();
		state.isDelinquent = isDelinquent;
		_state = state;
		emit StateUpdated(state.scaleFactor, isDelinquent);
	}
}
