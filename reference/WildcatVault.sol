// SPDX-License-Identifier: NONE
pragma solidity ^0.8.17;
import './interfaces/IWildcatPermissions.sol';
import './ERC2612.sol';
import './interfaces/IWildcatVaultFactory.sol';
import { SafeTransferLib } from './libraries/SafeTransferLib.sol';
// import { ScaleParametersCoder } from './types/ScaleParametersCoder.sol';

import './UncollateralizedDebtToken.sol';

// Also 4626, but not inheriting, rather rewriting
// Constructor doesn't take any arguments so that the bytecode is consistent for the create2 factory
contract WildcatVault is UncollateralizedDebtToken, ERC2612 {
	// using ScaleParametersCoder for ScaleParameters;
	using SafeTransferLib for address;
	using Math for uint256;

	error NotWhitelisted();

	uint256 internal immutable vaultFeePercentage = 10;

	uint256 internal collateralWithdrawn;

	// END: Vault specific parameters

	// BEGIN: Events
	event CollateralWithdrawn(address indexed recipient, uint256 assets);
	event CollateralDeposited(address indexed sender, uint256 assets);
	event VaultClosed(uint256 timestamp);
	event FeesCollected(address recipient, uint256 assets);
	event CollateralRequested(address indexed lender, uint256 assets);
	// END: Events

	// BEGIN: Modifiers
	modifier isVaultController() {
		address vaultController = IWildcatPermissions(wcPermissions)
			.isVaultController(address(this));
		require(msg.sender == vaultController);
		_;
	}

	modifier isWhitelisted() {
		if (
			!IWildcatPermissions(wcPermissions).isWhitelisted(
				address(this),
				msg.sender
			)
		) {
			revert NotWhitelisted();
		}
		_;
	}

	// END: Modifiers

	// BEGIN: Constructor
	constructor() ERC2612(name(), 'v1') {}

	// END: Constructor

	// BEGIN: Unique vault functionality

	/**
	 * @dev Returns the maximum amount of collateral that can be withdrawn.
	 */
	function maxCollateralToWithdraw() public view returns (uint256) {
		uint256 maximumToWithdraw = totalSupply().bipsMul(
			collateralizationRatioBips
		);
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
	 * @dev Fires an event from a given lender that logs a request for vault controller to deposit X collateral
	 */
	function requestCollateralDeposit(uint amountRequested) external {
		uint currBal = scaledBalanceOf[msg.sender];
		require(amountRequested <= currBal, "Requesting more collateral than held");
		emit CollateralRequested(msg.sender, amountRequested);
	}

	/**
	 * @dev Sets the vault APR to 0% and transfers the outstanding balance for full redemption
	 */
	function closeVault() external isVaultController {
		setAnnualInterestBips(0);
		uint256 currentlyHeld = totalAssets();
		uint256 outstanding = totalSupply() - currentlyHeld;
		asset.safeTransferFrom(msg.sender, address(this), outstanding);
		emit VaultClosed(block.timestamp);
	}

	function retrieveFees() external {
		(VaultState memory state, ) = _getCurrentStateAndAccrueFees();
		uint256 feesOwed = accruedProtocolFees;
		accruedProtocolFees = 0;

		uint256 feeShares = scaledBalanceOf[wcPermissions];
		if (feeShares > 0) {
			uint256 scaleFactor = state.getScaleFactor();
			uint256 feeSharesValue = feeShares.rayMul(scaleFactor);
			if (feeSharesValue + accruedProtocolFees <= totalAssets()) {
				feesOwed += feeSharesValue;
				scaledBalanceOf[wcPermissions] = 0;
				_state = state.setScaledTotalSupply(
					state.getScaledTotalSupply() - feeShares
				);
				emit Transfer(wcPermissions, address(0), feeShares);
			}
		}
		asset.safeTransfer(wcPermissions, feesOwed);
		emit FeesCollected(wcPermissions, feesOwed);
	}

	// END: Unique vault functionality

	function _approve(
		address _owner,
		address spender,
		uint256 amount
	) internal virtual override(UncollateralizedDebtToken, ERC2612) {
		return UncollateralizedDebtToken._approve(_owner, spender, amount);
	}
}
