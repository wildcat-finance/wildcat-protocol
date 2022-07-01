// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import "./ERC20.sol";

import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IWMPermissions.sol";
import "./interfaces/IWMRegistry.sol";
import "./interfaces/IWMVault.sol";
import "./interfaces/IWMVaultFactory.sol";

import "./libraries/SymbolHelper.sol";

// Also 4626, but not inheriting, rather rewriting
contract WMVault is ERC20 {

    // BEGIN: Vault specific parameters
    address public underlying;
    uint256 public availableCapacity;
    
    uint256 public COLLATERALISATION_RATIO;
    uint256 public ANNUAL_APR; // squeeze down to a uint40

    uint256 internal INTEREST_PER_SECOND;  // squeeze down to a uint40

    uint256 constant InterestDenominator = 1e12;

    struct User {
        uint184 balance;
        uint32 lastDisbursalTimestamp;
        // Extra space unused because balance can not exceed totalSupply
    }
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

    // Constructor doesn't take any arguments so that the bytecode is consistent for the create2 factory
    constructor() {
        
        // msg.sender will always be the factory, so don't need to encode this anywhere
        address vaultFactory = msg.sender;

        // set vault parameters from data currently set in the factory
        underlying = IWMVaultFactory(vaultFactory).factoryVaultUnderlying();
        availableCapacity = IWMVaultFactory(vaultFactory).factoryVaultAvailableCapacity();
        COLLATERALISATION_RATIO = IWMVaultFactory(vaultFactory).factoryVaultCollatRatio();
        ANNUAL_APR = IWMVaultFactory(vaultFactory).factoryVaultAnnualAPR();

        name = SymbolHelper.getPrefixedName("Wintermute ", underlying);
        symbol = SymbolHelper.getPrefixedSymbol("wmt", underlying);
    }



}