// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


// ============================== NOTICE ==============================
// This library was automatically generated with stackpacker.
// Be very careful about modifying it, as doing so incorrectly could
// result in corrupted reads/writes.
// ====================================================================

uint256 constant MaxUint1 = 0x01;
uint256 constant MaxUint112 = 0xffffffffffffffffffffffffffff;
uint256 constant MaxUint128 = 0xffffffffffffffffffffffffffffffff;
uint256 constant MaxUint16 = 0xffff;
uint256 constant MaxUint32 = 0xffffffff;
uint256 constant Panic_arithmetic = 0x11;
uint256 constant Panic_error_length = 0x24;
uint256 constant Panic_error_offset = 0x04;
uint256 constant Panic_error_signature = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
uint256 constant ScaleParameters_Delinquency_maskOut = 0x000000007fffffffffffffffffffffffffffffffffffffffffffffffffffffff;
uint256 constant ScaleParameters_InitialState_maskOut = 0xffffffff80000000000000000000000000000000000000007fffffffffffffff;
uint256 constant ScaleParameters_NewScaleInputs_maskOut = 0xffffffff80000000000000000000000000000000000000007fffffffffffffff;
uint256 constant ScaleParameters_NewScaleOutputs_maskOut = 0xffffffffffff8000000000000000000000000000000000007fffffffffffffff;
uint256 constant ScaleParameters_annualInterestBips_bitsAfter = 0xcf;
uint256 constant ScaleParameters_annualInterestBips_maskOut = 0xffffffff80007fffffffffffffffffffffffffffffffffffffffffffffffffff;
uint256 constant ScaleParameters_isDelinquent_bitsAfter = 0xff;
uint256 constant ScaleParameters_isDelinquent_maskOut = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
uint256 constant ScaleParameters_lastInterestAccruedTimestamp_bitsAfter = 0x3f;
uint256 constant ScaleParameters_lastInterestAccruedTimestamp_maskOut = 0xffffffffffffffffffffffffffffffffffffffff800000007fffffffffffffff;
uint256 constant ScaleParameters_scaleFactor_bitsAfter = 0x5f;
uint256 constant ScaleParameters_scaleFactor_maskOut = 0xffffffffffff80000000000000000000000000007fffffffffffffffffffffff;
uint256 constant ScaleParameters_timeDelinquent_bitsAfter = 0xdf;
uint256 constant ScaleParameters_timeDelinquent_maskOut = 0x800000007fffffffffffffffffffffffffffffffffffffffffffffffffffffff;
uint256 constant VaultSupply_maxTotalSupply_bitsAfter = 0x80;
uint256 constant VaultSupply_maxTotalSupply_maskOut = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;
uint256 constant VaultSupply_scaledTotalSupply_maskOut = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;