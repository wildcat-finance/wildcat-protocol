// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;
import './interfaces/IWildcatPermissions.sol';
import './interfaces/IWildcatVaultFactory.sol';
import { SafeTransferLib } from './libraries/SafeTransferLib.sol';
import { VaultStateCoder } from './types/VaultStateCoder.sol';

import './UncollateralizedDebtToken.sol';

// Also 4626, but not inheriting, rather rewriting
// Constructor doesn't take any arguments so that the bytecode is consistent for the create2 factory
contract WildcatVault is UncollateralizedDebtToken() {
	using VaultStateCoder for VaultState;

	error NotWhitelisted();


	uint256 internal immutable vaultFeePercentage = 10;

	uint256 internal collateralWithdrawn;

	// END: Vault specific parameters

	// BEGIN: Events
	event CollateralWithdrawn(address indexed recipient, uint256 assets);
	event CollateralDeposited(address indexed sender, uint256 assets);
	event VaultClosed(uint256 timestamp);
	event FeesCollected(address recipient, uint256 assets);
	// END: Events

	// BEGIN: Modifiers
	modifier isVaultController() {
		address vaultController = IWildcatPermissions(wcPermissions).isVaultController(address(this)); 
		require(msg.sender == vaultController);
		_;
	}

	modifier isWhitelisted() {
		if (!IWildcatPermissions(wcPermissions).isWhitelisted(address(this), msg.sender)) {
			revert NotWhitelisted();
		}
		_;
	}

	// END: Modifiers

	// BEGIN: Constructor

	// END: Constructor

	// BEGIN: Unique vault functionality

	/**
	 * @dev Returns the maximum amount of collateral that can be withdrawn.
	 */
	function maxCollateralToWithdraw() public view returns (uint256) {
		uint256 maximumToWithdraw = (totalSupply() * collateralizationRatioBips) / 100;
		uint256 collateral = availableAssets();
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
		isVaultController
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

	function depositCollateral(uint256 assets) external isVaultController {
		SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), assets);
		if (assets > collateralWithdrawn) {
			collateralWithdrawn = 0;
		} else {
			collateralWithdrawn -= assets;
		}
		emit CollateralDeposited(address(this), assets);
	}

	/**
	* @dev Sets the vault APR to 0% and transfers the outstanding balance for full redemption
	 */
	function closeVault() external isVaultController {
		setAnnualInterestBips(0);
		uint currentlyHeld = IERC20(asset).balanceOf(address(this));
		uint outstanding = totalSupply() - currentlyHeld;
		SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), outstanding);
		emit VaultClosed(block.timestamp);
	}

	function retrieveFees() external {
		address recipient = wcPermissions;
		uint feesToCollect = balanceOf(recipient);
		SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), feesToCollect);
		emit FeesCollected(recipient, feesToCollect);
	}

	// END: Unique vault functionality
}
