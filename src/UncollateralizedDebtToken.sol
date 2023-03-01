// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './libraries/StringPackerPrefixer.sol';
import './interfaces/IERC20.sol';
import './types/ScaleParametersCoder.sol';
import './types/VaultSupplyCoder.sol';
import './libraries/SafeTransferLib.sol';
import './libraries/Math.sol';
import './interfaces/IWildcatPermissions.sol';
import { IWildcatVaultFactory } from './interfaces/IWildcatVaultFactory.sol';
import { IERC20Metadata } from './interfaces/IERC20Metadata.sol';

uint256 constant UnknownNameQueryError_selector = 0xed3df7ad00000000000000000000000000000000000000000000000000000000;
uint256 constant UnknownSymbolQueryError_selector = 0x89ff815700000000000000000000000000000000000000000000000000000000;
uint256 constant NameFunction_selector = 0x06fdde0300000000000000000000000000000000000000000000000000000000;
uint256 constant SymbolFunction_selector = 0x95d89b4100000000000000000000000000000000000000000000000000000000;

contract UncollateralizedDebtToken is StringPackerPrefixer {
	using SafeTransferLib for address;
	using ScaleParametersCoder for ScaleParameters;
	using VaultSupplyCoder for VaultSupply;
	using Math for uint256;

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

	/*//////////////////////////////////////////////////////////////
                      Storage and Constants
//////////////////////////////////////////////////////////////*/

  address internal _owner;

	ScaleParameters internal _state;

	VaultSupply internal _vaultSupply;

	uint96 public accruedProtocolFees;

	mapping(address => uint256) public scaledBalanceOf;

	mapping(address => mapping(address => uint256)) public allowance;

	uint256 public immutable collateralizationRatioBips;

	uint256 public immutable interestFeeBips;

  uint256 public /* immutable */ penaltyFeeBips;

	address public immutable wcPermissions;

	address public immutable asset;

	bytes32 private immutable _packedName;

	bytes32 private immutable _packedSymbol;

	uint8 public immutable decimals;

	/*//////////////////////////////////////////////////////////////
                            Modifiers
//////////////////////////////////////////////////////////////*/

	modifier onlyOwner() {
		if (msg.sender != owner()) revert NotOwner();
		_;
	}

	constructor() {
		(
			address _asset,
			bytes32 _namePrefix,
			bytes32 _symbolPrefix,
			address _owner,
			address _vaultPermissions,
			uint256 _maxTotalSupply,
			uint256 _annualInterestBips,
			uint256 _collateralizationRatioBips,
			uint256 _interestFeeBips
		) = IWildcatVaultFactory(msg.sender).getVaultParameters();
		// Set asset metadata
		asset = _asset;
		_packedName = _getPackedPrefixedReturnValue(
			_unpackString(_namePrefix),
			_asset,
			NameFunction_selector,
			UnknownNameQueryError_selector
		);
		_packedSymbol = _getPackedPrefixedReturnValue(
			_unpackString(_symbolPrefix),
			_asset,
			SymbolFunction_selector,
			UnknownSymbolQueryError_selector
		);
		decimals = IERC20Metadata(_asset).decimals();
		_state = DefaultScaleParameters.setInitialState(
			_annualInterestBips,
			RayOne,
			block.timestamp
		);
		_vaultSupply = DefaultVaultSupply.setMaxTotalSupply( _maxTotalSupply);
		if (_collateralizationRatioBips > BipsOne) {
			revert CollateralizationRatioTooHigh();
		}
		if (_interestFeeBips > BipsOne) {
			revert InterestFeeTooHigh();
		}
		collateralizationRatioBips = _collateralizationRatioBips;
		interestFeeBips = _interestFeeBips;
		wcPermissions = _vaultPermissions;
	}

	/*//////////////////////////////////////////////////////////////
                        Management Actions
//////////////////////////////////////////////////////////////*/

	// TODO: how should the maximum capacity be represented here? flat amount of base asset? inflated per scale factor?
	/**
	 * @dev Sets the maximum total supply - this only limits deposits and
	 * does not affect interest accrual.
	 */
	function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyOwner {
		// Ensure new maxTotalSupply is not less than current totalSupply
		if (_maxTotalSupply < totalSupply()) {
			revert NewMaxSupplyTooLow();
		}
		// Store new vault supply with updated maxTotalSupply
		_vaultSupply = _vaultSupply.setMaxTotalSupply(_maxTotalSupply);
		emit MaxSupplyUpdated(_maxTotalSupply);
	}

	function setAnnualInterestBips(uint256 _annualInterestBips) public onlyOwner {
		(ScaleParameters state, ) = _getCurrentStateAndAccrueFees();
		_state = state.setAnnualInterestBips(_annualInterestBips);
	}

	/*//////////////////////////////////////////////////////////////
                            Mint & Burn
//////////////////////////////////////////////////////////////*/

	function depositUpTo(uint256 amount, address to)
		public
		virtual
		returns (uint256 actualAmount)
	{
		// Get current scale factor
		(ScaleParameters state, ) = _getCurrentStateAndAccrueFees();
		uint256 scaleFactor = state.getScaleFactor();

		// Reduce amount if it would exceed totalSupply
		actualAmount = Math.min(amount, _getMaximumDeposit(state, scaleFactor));

		// Scale the actual mint amount
		uint256 scaledAmount = actualAmount.rayDiv(scaleFactor);

		// Transfer deposit from caller
		asset.safeTransferFrom(msg.sender, address(this), amount);

		// Increase user's balance
		scaledBalanceOf[to] += scaledAmount;
		emit Transfer(address(0), to, actualAmount);

		// Increase supply
		unchecked {
			// If user's balance did not overflow uint256, neither will supply
			// Coder checks for overflow of uint96
			_vaultSupply = _vaultSupply.setScaledTotalSupply(
				_vaultSupply.getScaledTotalSupply() + scaledAmount
			);
		}
		_state = state;
	}

	function deposit(uint256 amount, address to) external virtual {
		if (depositUpTo(amount, to) != amount) {
			revert MaxSupplyExceeded();
		}
	}

	function withdraw(uint256 amount, address to) external virtual {
		// Scale `amount`
		(ScaleParameters state, ) = _getCurrentStateAndAccrueFees();
		uint256 scaleFactor = state.getScaleFactor();
		uint256 scaledAmount = amount.rayDiv(scaleFactor);

		// Reduce caller's balance
		scaledBalanceOf[msg.sender] -= scaledAmount;
		emit Transfer(msg.sender, address(0), amount);

		// Reduce supply
		unchecked {
			// If user's balance did not underflow, neither will supply
			_vaultSupply = _vaultSupply.setScaledTotalSupply(
				_vaultSupply.getScaledTotalSupply() - scaledAmount
			);
		}

		// Transfer withdrawn assets to `user`
		asset.safeTransfer(to, amount);
	}

	/*//////////////////////////////////////////////////////////////
                        External Getters
//////////////////////////////////////////////////////////////*/

	function owner() public view returns (address) {
		return _owner;
	}

	/**
	 * @notice Returns the normalized balance of `account` with interest.
	 */
	function balanceOf(address account) public view virtual returns (uint256) {
		ScaleParameters state = _getCurrentState();
		return scaledBalanceOf[account].rayMul(state.getScaleFactor());
	}

	/**
	 * @notice Returns the normalized total supply with interest.
	 */
	function totalSupply() public view virtual returns (uint256) {
		ScaleParameters state = _getCurrentState();
		return _vaultSupply.getScaledTotalSupply().rayMul(state.getScaleFactor());
	}

	function stateParameters()
		public
		view
		returns (
  // Maximum allowed token supply
  uint256 maxTotalSupply,
  // Scaled token supply (divided by scaleFactor)
	uint256 scaledTotalSupply,
  // Whether vault is currently delinquent (collateral under requirement)
	bool isDelinquent,
  // Seconds in delinquency status
	uint256 timeDelinquent,
	// Max APR is ~655%
	uint256 annualInterestBips,
	// Max scale factor is ~52m
	uint256 scaleFactor,
  // Last time vault accrued interest
	uint256 lastInterestAccruedTimestamp
		)
	{
    (maxTotalSupply, scaledTotalSupply) = _vaultSupply.decode();
    (
      isDelinquent,
timeDelinquent,
annualInterestBips,
scaleFactor,
lastInterestAccruedTimestamp
    ) = _state.decode();
	}

	function currentAnnualInterestBips()
		public
		view
		returns (uint256)
	{
    return _state.getAnnualInterestBips();
	}

	function currentScaleFactor() public view returns (uint256 scaleFactor) {
		(ScaleParameters state, , ) = _calculateInterestAndFees(_state);
		scaleFactor = state.getScaleFactor();
	}

	function pendingFees() public view returns (uint256 pendingFees) {
		(, pendingFees, ) = _calculateInterestAndFees(_state);
	}

	function maxTotalSupply() public view virtual returns (uint256) {
		return _vaultSupply.getMaxTotalSupply();
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
		return totalAssets().subMinZero(accruedProtocolFees);
	}

	function name() public view returns (string memory) {
		return _unpackString(_packedName);
	}

	function symbol() public view returns (string memory) {
		return _unpackString(_packedSymbol);
	}

	/*//////////////////////////////////////////////////////////////
                      Internal State Handlers
//////////////////////////////////////////////////////////////*/

	function _getUpdatedScaleFactor() internal returns (uint256) {
		return _getUpdatedStateAndAccrueFees().getScaleFactor();
	}

	/**
	 * @dev Returns ScaleParameters with interest since last update accrued to the cache
	 * and updates storage with accrued protocol fees.
	 * Used in functions that make additional changes to the vault state.
	 * @return state Vault state after interest is accrued - does not match stored object.
	 */
	function _getCurrentStateAndAccrueFees()
		internal
		returns (
			ScaleParameters, /* scaleParameters */
			bool /* didUpdate */
		)
	{
		(
			ScaleParameters state,
			uint256 feesAccrued,
			bool didUpdate
		) = _calculateInterestAndFees(_state);
		if (didUpdate) {
			// @todo
			// Update queries for collateral availability to reduce it by pending fees
			// Otherwise, fees could cause collateral to be insufficient for a withdrawal that seemed fine on the front end
			// Options for pool has sufficient assets for fee withdrawal:
			// 1. Transfer
			// 2. Update a sum of pending fees that does not count accrue interest or affect the supply
			// 3. Always mint shares
			// Options for pool has insufficient assets for fee withdrawal:
			// 1. Mint shares - borrower can pay interest on fees if they are not maintaining collateral requirements
			// 2.

			// If pool has insufficient assets to transfer fees, treat fees as deposited assets
			// to mint shares for fee recipient. This results in interest being charged on fees
			// when the borrower does not maintain collateralization requirements.
			if (totalAssets() < feesAccrued) {
				uint256 scaledFee = feesAccrued.rayDiv(state.getScaleFactor());
				_vaultSupply = _vaultSupply.setScaledTotalSupply(
					_vaultSupply.getScaledTotalSupply() + scaledFee
				);
				scaledBalanceOf[wcPermissions] += scaledFee;
				emit Transfer(address(0), wcPermissions, scaledFee);
			} else {
				// @todo safe cast / demonstrate why not needed
				accruedProtocolFees += uint96(feesAccrued);
			}
		}
		return (state, didUpdate);
	}

	/**
	 * @dev Returns ScaleParameters with interest since last update accrued to both the
	 * cached and stored vault states, and updates storage with accrued protocol fees.
	 * Used in functions that don't make additional changes to the vault state.
	 * @return state Vault state after interest is accrued - matches stored object.
	 */
	function _getUpdatedStateAndAccrueFees() internal returns (ScaleParameters) {
		(ScaleParameters state, bool didUpdate) = _getCurrentStateAndAccrueFees();
		if (didUpdate) {
			_state = state;
		}
		return state;
	}

	function _getCurrentState() internal view returns (ScaleParameters state) {
		(state, , ) = _calculateInterestAndFees(_state);
	}

	// @todo rename
	/**
	 * @dev Calculates interest and protocol fees accrued since last state update. and applies it to
	 * cached state returns protocol fees accrued.
	 *
	 * @param state Vault state
	 * @return state Cached state with updated scaleFactor and timestamp after accruing fees
	 * @return feesAccrued Protocol fees owed on interest
	 * @return didUpdate Whether interest has accrued since last update
	 */
	function _calculateInterestAndFees(ScaleParameters state)
		internal
		view
		returns (
			ScaleParameters, /* state */
			uint256, /* feesAccrued */
			bool /* didUpdate */
		)
	{
		(
			uint256 annualInterestBips,
			uint256 scaleFactor,
			uint256 lastInterestAccruedTimestamp
		) = state.getNewScaleInputs();
		uint256 timeElapsed;
		uint256 feesAccrued;
		unchecked {
			timeElapsed = block.timestamp - lastInterestAccruedTimestamp;
		}

		bool didUpdate = timeElapsed > 0;

		if (didUpdate) {
			uint256 scaleFactorDelta;
			{
				uint256 interestAccrued;
				uint256 interestPerSecond = annualInterestBips
					.annualBipsToRayPerSecond();
				assembly {
					// Calculate interest accrued since last update
					interestAccrued := mul(timeElapsed, interestPerSecond)
				}
				// Compound growth of scaleFactor
				scaleFactorDelta = scaleFactor.rayMul(interestAccrued);
			}
			if (interestFeeBips > 0) {
				uint256 scaledSupply = _vaultSupply.getScaledTotalSupply();
				// Calculate fees accrued to protocol
				feesAccrued = scaledSupply.rayMul(
					scaleFactorDelta.bipsMul(interestFeeBips)
				);
				// Subtract fee
				scaleFactorDelta = scaleFactorDelta.bipsMul(BipsOne - interestFeeBips);
			}
			// Update scaleFactor and timestamp
			state = state.setNewScaleOutputs(
				scaleFactor + scaleFactorDelta,
				block.timestamp
			);
		}

		return (state, feesAccrued, didUpdate);
	}

	function _getMaximumDeposit(ScaleParameters state, uint256 scaleFactor)
		internal
		view
		returns (uint256)
	{
		uint256 _totalSupply = _vaultSupply.getScaledTotalSupply().rayMul(scaleFactor);
		uint256 _maxTotalSupply = maxTotalSupply();
		return _maxTotalSupply.subMinZero(_totalSupply);
	}

	/*//////////////////////////////////////////////////////////////
                          ERC20 Actions
//////////////////////////////////////////////////////////////*/

	function approve(address spender, uint256 amount)
		external
		virtual
		returns (bool)
	{
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

	function transfer(address recipient, uint256 amount)
		external
		virtual
		returns (bool)
	{
		_transfer(msg.sender, recipient, amount);
		return true;
	}

	function _approve(
		address _owner,
		address spender,
		uint256 amount
	) internal virtual {
		allowance[_owner][spender] = amount;
		emit Approval(_owner, spender, amount);
	}

	function _transfer(
		address from,
		address to,
		uint256 amount
	) internal virtual {
		uint256 scaleFactor = _getUpdatedScaleFactor();
		uint256 scaledAmount = amount.rayDiv(scaleFactor);
		scaledBalanceOf[from] -= scaledAmount;
		unchecked {
			scaledBalanceOf[to] += scaledAmount;
		}
		emit Transfer(from, to, amount);
	}
}
