// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import './interfaces/IERC20.sol';
import './interfaces/IWildcatPermissions.sol';
import './interfaces/IWildcatVaultFactory.sol';
import { SafeTransferLib } from './libraries/SafeTransferLib.sol';
import { VaultStateCoder } from './types/VaultStateCoder.sol';

import './UncollateralizedDebtToken.sol';

// Also 4626, but not inheriting, rather rewriting
contract WildcatVault is UncollateralizedDebtToken {
	using VaultStateCoder for VaultState;

	error NotWhitelisted();

	// BEGIN: Vault specific parameters
	IWildcatPermissions public immutable wcPermissions;

	uint256 internal collateralWithdrawn;

	// END: Vault specific parameters

	// BEGIN: Events
	event CollateralWithdrawn(address indexed recipient, uint256 assets);
	event CollateralDeposited(address indexed sender, uint256 assets);
	event VaultClosed(uint256 timestamp);
	// END: Events

	// BEGIN: Modifiers
	modifier isWildcatController() {
		address controller = wcPermissions.controller();
		require(msg.sender == controller);
		_;
	}

	modifier isWhitelisted() {
		if (!wcPermissions.isWhitelisted(msg.sender)) {
			revert NotWhitelisted();
		}
		_;
	}

	// END: Modifiers

	// BEGIN: Constructor
	// Constructor doesn't take any arguments so that the bytecode is consistent for the create2 factory
	constructor()
		UncollateralizedDebtToken(
			IWildcatVaultFactory(msg.sender).factoryVaultUnderlying(),
			IWildcatVaultFactory(msg.sender).factoryVaultNamePrefix(),
			IWildcatVaultFactory(msg.sender).factoryVaultSymbolPrefix(),
			IWildcatVaultFactory(msg.sender).factoryPermissionRegistry(),
			IWildcatVaultFactory(msg.sender).factoryVaultMaximumCapacity(),
			IWildcatVaultFactory(msg.sender).factoryVaultAnnualAPR(),
			IWildcatVaultFactory(msg.sender).factoryVaultCollatRatio()
		)
	{
		wcPermissions = IWildcatPermissions(
			IWildcatVaultFactory(msg.sender).factoryPermissionRegistry()
		);
	}

	// END: Constructor

	// BEGIN: Unique vault functionality

	/**
	 * @dev Returns the maximum amount of collateral that can be withdrawn.
	 */
	function maxCollateralToWithdraw() public view returns (uint256) {
		uint256 maximumToWithdraw = (totalSupply() * collateralizationRatioBips) / 100;
		uint256 collateral = IERC20(asset).balanceOf(address(this));
		if (collateralWithdrawn > maximumToWithdraw) {
			return 0;
		}
		if (maximumToWithdraw - collateralWithdrawn > collateral) {
			return collateral;
		}
		return maximumToWithdraw - collateralWithdrawn;
	}

	function withdrawCollateral(address receiver, uint256 assets)
		external
		isWildcatController
	{
		uint256 maxAvailable = maxCollateralToWithdraw();
		require(
			assets <= maxAvailable,
			'trying to withdraw more than collat ratio allows'
		);
		SafeTransferLib.safeTransfer(asset, receiver, assets);
		collateralWithdrawn += assets;
		emit CollateralWithdrawn(receiver, assets);
	}

	function depositCollateral(uint256 assets) external isWildcatController {
		SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), assets);
		emit CollateralDeposited(address(this), assets);
	}

	/**
	* @dev Sets the vault APR to 0% and transfers the outstanding balance for full redemption
	 */
	function closeVault() external isWildcatController {
		setAnnualInterestBips(0);
		uint currentlyHeld = IERC20(asset).balanceOf(address(this));
		uint outstanding = totalSupply() - currentlyHeld;
		SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), outstanding);
		emit VaultClosed(block.timestamp);
	}

	// END: Unique vault functionality
}
