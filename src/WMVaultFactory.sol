// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import "./interfaces/IWMPermissions.sol";
import "./interfaces/IWMVault.sol";

contract WMVaultFactory {

    address public factoryVaultUnderlying = address(0x00);
    address public factoryPermissionRegistry = address(0x00);

    // can shave these values down to appropriate uintX later
    uint public factoryVaultMaximumCapacity = 0;
    uint public factoryVaultAnnualAPR = 0;
    uint public factoryVaultCollatRatio = 0;



}