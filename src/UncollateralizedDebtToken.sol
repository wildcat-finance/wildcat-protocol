// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './WrappedAssetMetadata.sol';
import './ERC2612.sol';
import { DefaultVaultState, VaultState, VaultStateCoder } from './types/VaultStateCoder.sol';
import { Configuration, ConfigurationCoder } from './types/ConfigurationCoder.sol';
import './libraries/SafeTransferLib.sol';
import './libraries/Math.sol';

int256 constant MinimumAnnualInterestBips = 0;

contract UncollateralizedDebtToken is WrappedAssetMetadata, ERC2612 {
	using SafeTransferLib for address;
	using VaultStateCoder for VaultState;
	using ConfigurationCoder for Configuration;
	using Math for uint256;
	using Math for int256;

  /// @notice Error thrown when deposit exceeds maxTotalSupply
	error MaxSupplyExceeded();

  /// @notice Error thrown when non-owner tries accessing owner-only actions
	error NotOwner();

  /// @notice Error thrown when new maxTotalSupply lower than totalSupply
	error NewMaxSupplyTooLow();

	// @todo Is this a reasonable limit?
	/// @notice Error thrown when interest rate is lower than -100%
	error InterestRateTooLow();

  /// @notice Error thrown when collateralization ratio higher than 100%
  error CollateralizationRatioTooHigh();

	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);
	event MaxSupplyUpdated(uint256 assets);

	/*//////////////////////////////////////////////////////////////
                        Storage and Constants
  //////////////////////////////////////////////////////////////*/

	VaultState internal _state;

	Configuration internal _configuration;

	mapping(address => uint256) public scaledBalanceOf;

	mapping(address => mapping(address => uint256)) public allowance;

  uint256 public immutable collateralizationRatioBips;

	/*//////////////////////////////////////////////////////////////
                              Modifiers
  //////////////////////////////////////////////////////////////*/

	modifier onlyOwner() {
		if (msg.sender != owner()) revert NotOwner();
		_;
	}

	constructor(
		address _asset,
		string memory namePrefix,
		string memory symbolPrefix,
		address _owner,
		uint256 _maxTotalSupply,
		int256 _annualInterestBips,
    uint256 _collateralizationRatioBips
	)
		WrappedAssetMetadata(namePrefix, symbolPrefix, _asset)
		ERC2612(name(), 'v1')
	{
		if (_annualInterestBips < MinimumAnnualInterestBips) {
			revert InterestRateTooLow();
		}
		_state = DefaultVaultState.setInitialState(
			_annualInterestBips,
			RayOne,
			block.timestamp
		);
		_configuration = ConfigurationCoder.encode(_owner, _maxTotalSupply);
    if (_collateralizationRatioBips > 10000) {
      revert CollateralizationRatioTooHigh();
    }
    collateralizationRatioBips = _collateralizationRatioBips;
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
		// Store new configuration with updated maxTotalSupply
		_configuration = _configuration.setMaxTotalSupply(_maxTotalSupply);
		emit MaxSupplyUpdated(_maxTotalSupply);
	}

	function setAnnualInterestBips(int256 _annualInterestBips)
		external
		onlyOwner
	{
		if (_annualInterestBips < MinimumAnnualInterestBips) {
			revert InterestRateTooLow();
		}
		_state = _getCurrentState().setAnnualInterestBips(_annualInterestBips);
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
		VaultState state = _getCurrentState();
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
			state = state.setScaledTotalSupply(
				state.getScaledTotalSupply() + scaledAmount
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
		VaultState state = _getCurrentState();
		uint256 scaleFactor = state.getScaleFactor();
		uint256 scaledAmount = amount.rayDiv(scaleFactor);

    // Reduce caller's balance
		scaledBalanceOf[msg.sender] -= scaledAmount;
		emit Transfer(msg.sender, address(0), amount);

    // Reduce supply
		unchecked {
			// If user's balance did not underflow, neither will supply
			_state = state.setScaledTotalSupply(
				state.getScaledTotalSupply() - scaledAmount
			);
		}

		// Transfer withdrawn assets to `user`
		asset.safeTransfer(to, amount);
	}

	/*//////////////////////////////////////////////////////////////
                          External Getters
  //////////////////////////////////////////////////////////////*/

	function owner() public view returns (address) {
		return _configuration.getOwner();
	}

	/**
	 * @notice Returns the normalized balance of `account` with interest.
	 */
	function balanceOf(address account) public view virtual returns (uint256) {
		(uint256 scaleFactor, ) = _getCurrentScaleFactor(_state);
		return scaledBalanceOf[account].rayMul(scaleFactor);
	}

	/**
	 * @notice Returns the normalized total supply with interest.
	 */
	function totalSupply() public view virtual returns (uint256) {
		VaultState state = _state;
		(uint256 scaleFactor, ) = _getCurrentScaleFactor(state);
		return state.getScaledTotalSupply().rayMul(scaleFactor);
	}

	function stateParameters()
		public
		view
		returns (
			int256 annualInterestBips,
			uint256 scaledTotalSupply,
			uint256 scaleFactor,
			uint256 lastInterestAccruedTimestamp
		)
	{
		return _state.decode();
	}

	function currentScaleFactor() public view returns (uint256 scaleFactor) {
		(scaleFactor, ) = _getCurrentScaleFactor(_state);
	}

	function maxTotalSupply() public view virtual returns (uint256) {
		return _configuration.getMaxTotalSupply();
	}

	/*//////////////////////////////////////////////////////////////
                       Internal State Handlers
  //////////////////////////////////////////////////////////////*/

	function _getUpdatedScaleFactor() internal returns (uint256) {
		VaultState state = _state;
		(uint256 scaleFactor, bool changed) = _getCurrentScaleFactor(state);
		if (changed) {
			_state = state.setNewScaleOutputs(scaleFactor, block.timestamp);
		}
		return scaleFactor;
	}

	function _getCurrentState() internal view returns (VaultState state) {
		state = _state;
		(uint256 scaleFactor, bool changed) = _getCurrentScaleFactor(state);
		if (changed) {
			state = state.setNewScaleOutputs(scaleFactor, block.timestamp);
		}
	}

	/**
	 * @dev Returns scale factor at current time, with interest applied since the
	 * previous accrual but without updating the state.
	 */
	function _getCurrentScaleFactor(VaultState state)
		internal
		view
		returns (
			uint256, /* newScaleFactor */
			bool /* changed */
		)
	{
		(
			int256 annualInterestBips,
			uint256 scaleFactor,
			uint256 lastInterestAccruedTimestamp
		) = state.getNewScaleInputs();
		uint256 timeElapsed;
		unchecked {
			timeElapsed = block.timestamp - lastInterestAccruedTimestamp;
		}
		bool changed = timeElapsed > 0;
		if (changed) {
			int256 newInterest;
			int256 interestPerSecond = annualInterestBips.annualBipsToRayPerSecond();
			assembly {
				// Calculate interest accrued since last update
				newInterest := mul(timeElapsed, interestPerSecond)
			}
			// Calculate change to scale factor
			int256 scaleFactorChange = scaleFactor.rayMul(newInterest);
			assembly {
				scaleFactor := add(scaleFactor, scaleFactorChange)
				// Total scaleFactor must not underflow
				if slt(scaleFactor, 0) {
					mstore(0, Panic_error_signature)
					mstore(Panic_error_offset, Panic_arithmetic)
					revert(0, Panic_error_length)
				}
			}
		}
		return (scaleFactor, changed);
	}

	function _getMaximumDeposit(VaultState state, uint256 scaleFactor)
		internal
		view
		returns (uint256)
	{
		uint256 _totalSupply = state.getScaledTotalSupply().rayMul(scaleFactor);
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
	) internal virtual override {
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
