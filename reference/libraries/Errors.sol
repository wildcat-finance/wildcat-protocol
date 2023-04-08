// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

uint256 constant Panic_CompilerPanic = 0x00;
uint256 constant Panic_AssertFalse = 0x01;
uint256 constant Panic_Arithmetic = 0x11;
uint256 constant Panic_DivideByZero = 0x12;
uint256 constant Panic_InvalidEnumValue = 0x21;
uint256 constant Panic_InvalidStorageByteArray = 0x22;
uint256 constant Panic_EmptyArrayPop = 0x31;
uint256 constant Panic_ArrayOutOfBounds = 0x32;
uint256 constant Panic_MemoryTooLarge = 0x41;
uint256 constant Panic_UninitializedFunctionPointer = 0x51;

uint256 constant Panic_ErrorSelector = 0x4e487b71;
uint256 constant Panic_ErrorCodePointer = 0x20;
uint256 constant Panic_ErrorLength = 0x24;
uint256 constant Error_SelectorPointer = 0x1c;