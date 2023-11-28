// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import { ModifierLocals, SphereXProtectedBase } from './SphereXProtectedBase.sol';

/**
 * @title SphereX base Customer contract template
 * @dev notice this is an abstract
 */
abstract contract SphereXProtected is SphereXProtectedBase(msg.sender, address(0), address(0)) {

}