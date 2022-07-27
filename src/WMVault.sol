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
contract WMVault is ERC20, UncollateralizedDebtToken {
    using VaultStateCoder for VaultState;

    VaultState public globalState;

    // BEGIN: Vault specific parameters
    address internal wmPermissionAddress;

    UncollateralizedDebtToken public immutable debtToken;

    uint256 public availableCapacity;
    uint256 public capacityRemaining;

    uint256 internal _totalSupply;

    uint256 constant InterestDenominator = 1e12;

    struct User {
        uint184 balance;
        uint32 lastDisbursalTimestamp;
        // Extra space unused because balance can not exceed totalSupply
    }

    mapping(address => User) users;
    // END: Vault specific parameters

    // BEGIN: Events

    // ERC4626
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    // Vault Specific
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
    constructor() {
        // msg.sender will always be the factory, so don't need to encode this anywhere
        address vaultFactory = msg.sender;

        wmPermissionAddress = IWMVaultFactory(vaultFactory).factoryPermissionRegistry();

        // retrieve vault parameters from data currently set in the factory
        address underlying              = IWMVaultFactory(vaultFactory).factoryVaultUnderlying();
        uint256 maximumCapacity         = IWMVaultFactory(vaultFactory).factoryVaultMaximumCapacity();
        uint256 COLLATERALISATION_RATIO = IWMVaultFactory(vaultFactory).factoryVaultCollatRatio();
        uint256 ANNUAL_APR              = IWMVaultFactory(vaultFactory).factoryVaultAnnualAPR();

        // Defining this here so that there's a query available for any front-ends
        availableCapacity   = maximumCapacity;

        // TODO: make sure that wmPermissionAddress can change relevant ownership down the road
        debtToken = new UncollateralizedDebtToken(underlying, "Wintermute ", "wmt", wmPermissionAddress, maximumCapacity, COLLATERALISATION_RATIO, ANNUAL_APR);
    }
    // END: Constructor

    function _getUser(address _user) internal returns (User storage) {
        return users[_user];
    }

    function totalSupply() external view  override returns (uint256) {
        return _accrueInterest(_totalSupply, globalState.getLastInterestAccruedTimestamp());
    }

    function balanceOf(address account) public view override returns (uint256) {
		User storage user = users[account];
		return _accrueInterest(user.balance, user.lastDisbursalTimestamp);
    }

	function _accrueInterest(uint256 amount, uint256 lastTimestamp) internal view returns (uint184) {
		uint256 timeElapsed = block.timestamp - lastTimestamp;
		uint256 interestAccruedNumerator = timeElapsed * uint256(globalState.getAnnualInterestBips());
        uint256 interestAccrued = (amount * interestAccruedNumerator) / InterestDenominator;
        return safeCastTo184(amount + interestAccrued);
	}

    function _accrueGlobalInterest() internal {
        _totalSupply = _accrueInterest(_totalSupply, globalState.getLastInterestAccruedTimestamp());
        globalState.setLastInterestAccruedTimestamp(block.timestamp);
	}

    function _beforeMint(address to, uint256 amount, uint256) internal override {
        // TODO: flesh this out
    }

    function _mint(address to, uint256 rawAmount) internal override {
        _accrueGlobalInterest();
        User storage user = _getUser(to);
        uint184 amount = safeCastTo184(rawAmount);
        user.balance += amount;
        user.lastDisbursalTimestamp = safeCastTo32(block.timestamp);
        _totalSupply += amount;
        availableCapacity -= amount;
	}

    function _burn(address to, uint256 rawAmount) internal override {
        _accrueGlobalInterest();
        User storage user = _getUser(to);
        uint184 amount = safeCastTo184(rawAmount);
        user.balance -= amount;
        _totalSupply -= amount;
        availableCapacity += amount;
	}

    function _transfer(address from, address to, uint256 rawAmount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
		uint184 amount = safeCastTo184(rawAmount);
		User storage src = _getUser(from);
		User storage dst = _getUser(to);
		src.balance -= amount;
		dst.balance += amount;
	}

    // BEGIN: ERC4626 FUNCTIONALITY

    function totalAssets() external view returns (uint256) {
        return _totalSupply;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return shares;
    }

    function maxDeposit(address) external view returns (uint256) {
        return availableCapacity;
    }
    
    function previewDeposit(uint256 assets) external view returns (uint256) {
        return assets;
    }
    
    function deposit(uint256 assets, address receiver) external returns (uint256) {
        require(IWMPermissions(wmPermissionAddress).isWhitelisted(receiver), "deposit: user not whitelisted");
        require(receiver != address(0), "deposit: issue to the zero address");
        require(assets <= availableCapacity, "deposit: mint more than capacity");
        SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), assets);
        _mint(receiver, assets);
        emit Deposit(msg.sender, receiver, assets, assets);
        return assets;
    }
    
    function maxMint(address) external view returns (uint256) {
        return availableCapacity;
    }
    
    function previewMint(uint256) external view returns (uint256) {
        return availableCapacity;
    }
    
    function mint(uint256 shares, address receiver) external returns (uint256) {
        require(IWMPermissions(wmPermissionAddress).isWhitelisted(receiver), "mint: user not whitelisted");
        require(receiver != address(0), "mint: issue to the zero address");
        require(shares <= availableCapacity, "mint: mint more than capacity");
        SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), shares);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, shares, shares);
        return shares;
    }
    
    function maxWithdraw(address) external view returns (uint256) {
        return capacityRemaining;
    }
    
    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return assets;
    }
    
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256) {
        require(assets <= capacityRemaining, "withdraw: insufficient capacity to withdraw");
        require(receiver != address(0), "withdraw: burn from the zero address");
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - assets;
        }
        _burn(owner, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, assets);
        SafeTransferLib.safeTransfer(asset, receiver, assets);
        return assets;
    }

    function maxRedeem(address) external view returns (uint256) {
        return capacityRemaining;
    }
    
    function previewRedeem(uint256 shares) external view returns (uint256) {
        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256) {
        require(shares <= capacityRemaining, "redeem: insufficient capacity to redeem");
        require(receiver != address(0), "redeem: burn from the zero address");
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, shares, shares);
        SafeTransferLib.safeTransfer(asset, receiver, shares);
        return shares;
    }

    // END: ERC4626 FUNCTIONALITY

    // BEGIN: Unique vault functionality
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

    // BEGIN: Typecasters
    function safeCastTo184(uint256 x) internal pure returns (uint184 y) {
        require(x < 1 << 184);

        y = uint184(x);
    }

    function safeCastTo32(uint256 x) internal pure returns (uint32 y) {
        require(x < 1 << 32);
        
        y = uint32(x);
    }
    // END: Typecasters
	


}