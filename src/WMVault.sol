// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import './interfaces/IERC20.sol';
import './interfaces/IWMPermissions.sol';
import './interfaces/IWMVaultFactory.sol';
import { SafeTransferLib } from './libraries/SafeTransferLib.sol';
import { VaultStateCoder } from './types/VaultStateCoder.sol';

import './UncollateralizedDebtToken.sol';


// Also 4626, but not inheriting, rather rewriting
contract WMVault is UncollateralizedDebtToken {
	using VaultStateCoder for VaultState;

  error NotWhitelisted();

	// BEGIN: Vault specific parameters
	IWMPermissions public immutable wmPermissions;

	uint256 internal collateralWithdrawn;

	// END: Vault specific parameters

	// BEGIN: Events
	event CollateralWithdrawn(address indexed recipient, uint256 assets);
	event CollateralDeposited(address indexed sender, uint256 assets);
	// END: Events

	// BEGIN: Modifiers
	modifier isWintermute() {
		address wintermute = wmPermissions.wintermute();
		require(msg.sender == wintermute);
		_;
	}

  modifier isWhitelisted() {
    if (!wmPermissions.isWhitelisted(msg.sender)) {
      revert NotWhitelisted();
    }
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
		wmPermissions = IWMPermissions(
      IWMVaultFactory(msg.sender).factoryPermissionRegistry()
    );
	}

	// END: Constructor

	// BEGIN: Unique vault functionality

	/**
	 * @dev Returns the maximum amount of collateral that can be withdrawn.
	 */
	function maxCollateralToWithdraw() public view returns (uint256) {
		uint256 maximumToWithdraw = (totalSupply() * collateralizationRatio) / 100;
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
		isWintermute
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

	function depositCollateral(uint256 assets) external isWintermute {
		SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), assets);
		emit CollateralDeposited(address(this), assets);
	}

	// END: Unique vault functionality
}
