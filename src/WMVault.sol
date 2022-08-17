// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import './interfaces/IERC20.sol';
import './interfaces/IERC20Metadata.sol';
import './interfaces/IWMPermissions.sol';
import './interfaces/IWMVault.sol';
import './interfaces/IWMVaultFactory.sol';

import './ERC20.sol';
import './WMPermissions.sol';

import './libraries/SymbolHelper.sol';

import { SafeTransferLib } from './libraries/SafeTransferLib.sol';
import { VaultStateCoder } from './types/VaultStateCoder.sol';

import './UncollateralizedDebtToken.sol';

// Also 4626, but not inheriting, rather rewriting
contract WMVault is UncollateralizedDebtToken {
	using VaultStateCoder for VaultState;

	VaultState public globalState;

	// BEGIN: Vault specific parameters
	address internal wmPermissionAddress;

	uint256 internal _totalSupply;

	uint256 constant InterestDenominator = 1e12;

	// END: Vault specific parameters

	// BEGIN: Events
	event CollateralWithdrawn(address indexed recipient, uint256 assets);
	event CollateralDeposited(address indexed sender, uint256 assets);
	event MaximumCapacityChanged(address vault, uint256 assets);
	// END: Events

	// BEGIN: Modifiers
	modifier isWintermute() {
		address wintermute = IWMPermissions(wmPermissionAddress).wintermute();
		require(msg.sender == wintermute);
		_;
	}

	// END: Modifiers

	// BEGIN: Constructor
	// Constructor doesn't take any arguments so that the bytecode is consistent for the create2 factory
	constructor()
		UncollateralizedDebtToken(
			IWMVaultFactory(msg.sender).factoryVaultUnderlying(),
			'Wintermute ',
			'wmt',
			IWMVaultFactory(msg.sender).factoryPermissionRegistry(),
			IWMVaultFactory(msg.sender).factoryVaultMaximumCapacity(),
			IWMVaultFactory(msg.sender).factoryVaultCollatRatio(),
			IWMVaultFactory(msg.sender).factoryVaultAnnualAPR()
		)
	{
		wmPermissionAddress = IWMVaultFactory(msg.sender)
			.factoryPermissionRegistry();
	}

	// END: Constructor

	// BEGIN: Unique vault functionality
	function deposit(uint256 amount, address user) external {
		require(
			WMPermissions(wmPermissionAddress).isWhitelisted(msg.sender),
			'deposit: user not whitelisted'
		);
		_mint(user, amount);
		SafeTransferLib.safeTransferFrom(asset, user, address(this), amount);
	}

	function withdraw(uint256 amount, address user) external {
		require(
			WMPermissions(wmPermissionAddress).isWhitelisted(msg.sender),
			'deposit: user not whitelisted'
		);
		_burn(user, amount);
	}

	event DebugEvent(uint);

	/**
	 * @dev Returns the maximum amount of collateral that can be withdrawn.
	 */
	function maxCollateralToWithdraw() public returns (uint256) {
		uint256 minimumCollateral = (ScaledBalanceToken.totalSupply() * collateralizationRatio) / 100;
		uint256 collateral = IERC20(asset).balanceOf(address(this));
		
		emit DebugEvent(minimumCollateral);
		emit DebugEvent(collateral);

		if (collateral < minimumCollateral) {
			return 0;
		}
		return collateral - minimumCollateral;
	}

	function withdrawCollateral(address receiver, uint256 assets)
		external
		isWintermute
	{
		uint256 maxAvailable = maxCollateralToWithdraw();
		require(
			assets <= maxAvailable,
			'trying to withdraw more than collat ratio allows'
		);
		SafeTransferLib.safeTransfer(asset, receiver, assets);
		emit CollateralWithdrawn(receiver, assets);
	}

	// TODO: how should the maximum capacity be represented here? flat amount of base asset? inflated per scale factor?
	/**
	 * @dev Sets the maximum total supply - this only limits deposits and does not affect interest accrual.
	 */
	function setMaxTotalSupply(uint256 _newCapacity)
		external
		isWintermute
		returns (uint256)
	{
		emit MaximumCapacityChanged(address(this), _newCapacity);
		return _newCapacity;
	}

	function depositCollateral(uint256 assets) external isWintermute {
		SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), assets);
		emit CollateralDeposited(address(this), assets);
	}

	// END: Unique vault functionality

	// BEGIN: State inspection functions
	function getCurrentScaleFactor() public view returns (uint256) {
		return globalState.getScaleFactor();
	}
	// END: State inspection functions
}
