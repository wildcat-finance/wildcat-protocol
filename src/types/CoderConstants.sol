// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;


// ============================== NOTICE ==============================
// This library was automatically generated with stackpacker.
// Be very careful about modifying it, as doing so incorrectly could
// result in corrupted reads/writes.
// ====================================================================

uint256 constant MaxInt16 = 0xffff;
uint256 constant MaxUint14 = 0x3fff;
uint256 constant MaxUint32 = 0xffffffff;
uint256 constant MaxUint97 = 0x01ffffffffffffffffffffffff;
uint256 constant Panic_arithmetic = 0x11;
uint256 constant Panic_error_length = 0x24;
uint256 constant Panic_error_offset = 0x04;
uint256 constant Panic_error_signature = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
uint256 constant VaultState_annualInterestBips_bitsAfter = 0xe2;
uint256 constant VaultState_annualInterestBips_maskOut = 0xfffc0003ffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
uint256 constant VaultState_collateralizationRatioBips_bitsAfter = 0xf2;
uint256 constant VaultState_collateralizationRatioBips_maskOut = 0x0003ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
uint256 constant VaultState_lastInterestAccruedTimestamp_maskOut = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000;
uint256 constant VaultState_scaleFactor_bitsAfter = 0x20;
uint256 constant VaultState_scaleFactor_maskOut = 0xfffffffffffffffffffffffffffffffe000000000000000000000000ffffffff;
uint256 constant VaultState_totalSupply_bitsAfter = 0x81;
uint256 constant VaultState_totalSupply_maskOut = 0xfffffffc000000000000000000000001ffffffffffffffffffffffffffffffff;