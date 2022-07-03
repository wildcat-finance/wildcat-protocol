// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IWMPermissions.sol";
import "./interfaces/IWMRegistry.sol";
import "./interfaces/IWMVault.sol";
import "./interfaces/IWMVaultFactory.sol";

import "./ERC20.sol";
import "./WMPermissions.sol";

import "./libraries/SymbolHelper.sol";

import {SafeTransferLib} from "./libraries/SafeTransferLib.sol";

// Also 4626, but not inheriting, rather rewriting
contract WMVault is ERC20 {
    using SafeTransferLib for ERC20;

    // BEGIN: Vault specific parameters
    address internal wmPermissionAddress;
    
    address public underlying;
    ERC20 public immutable underlyingERC20;

    uint256 public maximumCapacity;
    uint256 public availableCapacity;
    uint256 public capacityRemaining;
	uint32  public lastDisbursalTimestamp;

    uint256 internal _totalSupply;
    
    uint256 public COLLATERALISATION_RATIO;
    uint256 public ANNUAL_APR; // squeeze down to a uint40

    uint256 internal INTEREST_PER_SECOND;  // squeeze down to a uint40

    uint256 constant InterestDenominator = 1e12;

    struct User {
        uint184 balance;
        uint32 lastDisbursalTimestamp;
        // Extra space unused because balance can not exceed totalSupply
    }

    mapping(address => User) users;
    // END: Vault specific parameters

    // BEGIN: ERC20 Metadata 
    string public name;
    string public symbol;

    /** @dev ERC20 decimals */
    function decimals() external view returns (uint8) {
        try IERC20Metadata(underlying).decimals() returns (uint8 _decimals) {
            return _decimals;
        } catch {
            return 18;
        }
    }
    // END: ERC20 Metadata

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

        // set vault parameters from data currently set in the factory
        wmPermissionAddress     = IWMVaultFactory(vaultFactory).factoryPermissionRegistry();
        underlying              = IWMVaultFactory(vaultFactory).factoryVaultUnderlying();
        maximumCapacity         = IWMVaultFactory(vaultFactory).factoryVaultMaximumCapacity();
        COLLATERALISATION_RATIO = IWMVaultFactory(vaultFactory).factoryVaultCollatRatio();
        ANNUAL_APR              = IWMVaultFactory(vaultFactory).factoryVaultAnnualAPR();

        INTEREST_PER_SECOND     = ANNUAL_APR / 365 days;
        availableCapacity       = maximumCapacity;

        underlyingERC20         = ERC20(underlying);

        name   = SymbolHelper.getPrefixedName("Wintermute ", underlying);
        symbol = SymbolHelper.getPrefixedSymbol("wmt", underlying);
    }
    // END: Constructor

    function _getUser(address _user) internal returns (User storage) {
        return users[_user];
    }

    function totalSupply() external view  override returns (uint256) {
        return _accrueInterest(_totalSupply, lastDisbursalTimestamp);
    }

    function balanceOf(address account) public view override returns (uint256) {
		User storage user = users[account];
		return _accrueInterest(user.balance, user.lastDisbursalTimestamp);
    }

	function _accrueInterest(uint256 amount, uint256 lastTimestamp) internal view returns (uint184) {
		uint256 timeElapsed = block.timestamp - lastTimestamp;
		uint256 interestAccruedNumerator = timeElapsed * uint256(INTEREST_PER_SECOND);
        uint256 interestAccrued = (amount * interestAccruedNumerator) / InterestDenominator;
        return safeCastTo184(amount + interestAccrued);
	}

    function _accrueGlobalInterest() internal {
        _totalSupply = _accrueInterest(_totalSupply, lastDisbursalTimestamp);
        lastDisbursalTimestamp = safeCastTo32(block.timestamp);
	}

    function _mint(address to, uint256 rawAmount) internal override {
        require(to != address(0), "ERC20: mint to the zero address");
        require(rawAmount <= availableCapacity, "_mint: mint more than capacity");
        _accrueGlobalInterest();
        User storage user = _getUser(to);
        uint184 amount = safeCastTo184(rawAmount);
        user.balance += amount;
        user.lastDisbursalTimestamp = safeCastTo32(block.timestamp);
        _totalSupply += amount;
        availableCapacity -= amount;
	}

    function _burn(address to, uint256 rawAmount) internal override {
        require(to != address(0), "ERC20: burn from the zero address");
        _accrueGlobalInterest();
        User storage user = _getUser(to);
        uint184 amount = safeCastTo184(rawAmount);
        user.balance -= amount;
        _totalSupply -= amount;
        availableCapacity += amount; // TODO: add a check here that you're not exceeding maximumCapacity
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

    function asset() external view returns (address assetTokenAddress) {
        return underlying;
    }

    function totalAssets() external view returns (uint256 totalManagedAssets) {
        return _totalSupply;
    }

    function convertToShares(uint256 assets) external view returns (uint256 shares) {
        return assets;
    }

    function convertToAssets(uint256 shares) external view returns (uint256 assets) {
        return shares;
    }

    function maxDeposit(address receiver) external view returns (uint256 maxAssets) {
        return availableCapacity;
    }
    
    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return assets;
    }
    
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        underlyingERC20.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, assets);
        emit Deposit(msg.sender, receiver, assets, assets);
    }
    
    function maxMint(address receiver) external view returns (uint256 maxShares) {
        return availableCapacity;
    }
    
    function previewMint(uint256 shares) external view returns (uint256 assets) {
        return availableCapacity;
    }
    
    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        underlyingERC20.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, assets);
        emit Deposit(msg.sender, receiver, assets, assets);
    }
    
    function maxWithdraw(address owner) external view returns (uint256 maxAssets) {
        return capacityRemaining;
    }
    
    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        return assets;
    }
    
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        require(shares <= capacityRemaining, "insufficient capacity to withdraw");
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        underlyingERC20.safeTransfer(receiver, assets);
    }

    function maxRedeem(address owner) external view returns (uint256 maxShares) {
        return capacityRemaining;
    }
    
    function previewRedeem(uint256 shares) external view returns (uint256 assets) {
        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        require(shares <= capacityRemaining, "insufficient capacity to redeem");
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        underlyingERC20.safeTransfer(receiver, assets);
    }

    // END: ERC4626 FUNCTIONALITY

    // BEGIN: Unique vault functionality
    function maxCollateralToWithdraw() public view returns (uint256 assets) {
        // TODO: how are we encoding COLLATERALISATION_RATIO? How many decimals? Could use InterestDenominator here?
        return (availableCapacity * COLLATERALISATION_RATIO) / 100;
    }

    function withdrawCollateral() external isWintermute() returns (uint256 assets) {

    }

    function adjustMaximumCapacity() external isWintermute() returns (uint256 assets) {

    }

    function depositCollateral() external isWintermute() returns (uint256 assets) {

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