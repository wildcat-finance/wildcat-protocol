// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import "./interfaces/IWMPermissions.sol";
import "./interfaces/IWMRegistry.sol";
import "./interfaces/IWMVault.sol";

import "./WMVault.sol";
import "./WMRegistry.sol";

contract WMVaultFactory {

    address internal wmPermissionAddress;

    IWMRegistry internal wmRegistry;

    address public factoryVaultUnderlying = address(0x00);
    address public factoryPermissionRegistry = address(0x00);

    // can shave these values down to appropriate uintX later
    uint public factoryVaultMaximumCapacity = 0;
    uint public factoryVaultAnnualAPR = 0;
    uint public factoryVaultCollatRatio = 0;

    event WMVaultRegistered(address, address);

    modifier isWintermute() {
        address wintermute = IWMPermissions(wmPermissionAddress).wintermute();
        require(msg.sender == wintermute);
        _;
    }

    constructor(address _permissions) {
        wmPermissionAddress = _permissions;
        WMRegistry registry = new WMRegistry{salt: bytes32(0x0)}();
        wmRegistry = IWMRegistry(address(registry));
    }

    function deployVault(
        address _underlying,
        address _permissions,
        uint _maxCapacity,
        uint _annualAPR,
        uint _collatRatio,
        bytes32 _salt
    ) public isWintermute() {
        
        // Set variables for vault creation
        factoryVaultUnderlying = _underlying;
        factoryPermissionRegistry = wmPermissionAddress;
        factoryVaultMaximumCapacity = _maxCapacity;
        factoryVaultAnnualAPR = _annualAPR;
        factoryVaultCollatRatio = _collatRatio;

        WMVault newVault = new WMVault{salt: _salt}();
        wmRegistry.registerVault(address(newVault));

        // Reset variables for gas refund
        factoryVaultUnderlying = address(0x00);
        factoryPermissionRegistry = address(0x00);
        factoryVaultMaximumCapacity = 0;
        factoryVaultAnnualAPR = 0;
        factoryVaultCollatRatio = 0;

    } 

}