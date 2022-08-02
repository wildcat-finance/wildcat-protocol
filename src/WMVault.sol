// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IWMPermissions.sol";
import "./interfaces/IWMVault.sol";
import "./interfaces/IWMVaultFactory.sol";

import "./ERC20.sol";
import "./WMPermissions.sol";

import "./libraries/SymbolHelper.sol";

import {SafeTransferLib} from "./libraries/SafeTransferLib.sol";
import {VaultStateCoder} from "./types/VaultStateCoder.sol";

import "./UncollateralizedDebtToken.sol";

// Also 4626, but not inheriting, rather rewriting
contract WMVault is UncollateralizedDebtToken {
    using VaultStateCoder for VaultState;

    VaultState public globalState;

    // BEGIN: Vault specific parameters
    address internal wmPermissionAddress;

    //UncollateralizedDebtToken public immutable debtToken;

    uint256 public availableCapacity;
    uint256 public capacityRemaining;

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
        UncollateralizedDebtToken(IWMVaultFactory(msg.sender).factoryVaultUnderlying(),
                                  "Wintermute",
                                  "wmt",
                                   IWMVaultFactory(msg.sender).factoryPermissionRegistry(),
                                   IWMVaultFactory(msg.sender).factoryVaultMaximumCapacity(),
                                   IWMVaultFactory(msg.sender).factoryVaultCollatRatio(),
                                   IWMVaultFactory(msg.sender).factoryVaultAnnualAPR())
    {
        wmPermissionAddress = IWMVaultFactory(msg.sender).factoryPermissionRegistry();

        // Defining this here so that there's a query available for any front-ends
        availableCapacity   = IWMVaultFactory(msg.sender).factoryVaultMaximumCapacity();

        // TODO: how to refer to this struct now to record it in debtToken?
        // debtToken = new UncollateralizedDebtToken(underlying, " ", "wmt", wmPermissionAddress, maximumCapacity, COLLATERALISATION_RATIO, ANNUAL_APR);
    }
    // END: Constructor

    function _mint(address to, uint256 rawAmount) internal override {
        ScaledBalanceToken._mintUpTo(to, rawAmount);
	}
    
    function _burn(address from, uint256 rawAmount) internal override {
        ScaledBalanceToken._burn(from, rawAmount);
    }

    // BEGIN: Unique vault functionality

    function getCurrentScaleFactor() public view returns (uint256) {
        return globalState.getScaleFactor();
    }

    function deposit(uint256 amount, address user) external returns (uint256) {
        require(WMPermissions(wmPermissionAddress).isWhitelisted(msg.sender), "deposit: user not whitelisted");
        ScaledBalanceToken._mintUpTo(user, amount);
    }

    function maxCollateralToWithdraw() public view returns (uint256) {
        // TODO: how are we encoding COLLATERALISATION_RATIO? How many decimals? Could use InterestDenominator here?
        // At present we're assuming a float 0 <= x < 100
        return (availableCapacity * collateralizationRatio) / 100;
    }

    function withdrawCollateral(address receiver, uint256 assets) external isWintermute() {
        uint256 maxAvailable = maxCollateralToWithdraw();
        require(assets <= maxAvailable, "trying to withdraw more than collat ratio allows");
        SafeTransferLib.safeTransfer(asset, receiver, assets);
        emit CollateralWithdrawn(receiver, assets);
    }

    function adjustMaximumCapacity(uint256 _newCapacity) external isWintermute() returns (uint256) {
        require(_newCapacity > capacityRemaining, "Cannot reduce max exposure to below outstanding");
        // TODO: remove this whole function, it's part of the UncollateralizedDebtToken now
        // maximumCapacity = _newCapacity;
        emit MaximumCapacityChanged(address(this), _newCapacity);
        return _newCapacity;
    }

    function depositCollateral(uint256 assets) external isWintermute() {
        // TODO: require that the token being sent is the underlying
        SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), assets);
        emit CollateralDeposited(address(this), assets);
    }
    // END: Unique vault functionality
   
}