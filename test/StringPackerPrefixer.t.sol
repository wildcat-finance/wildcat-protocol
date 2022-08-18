// SPDX-License-Identifier: NONE
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "./helpers/Metadata.sol";
import "./helpers/ExternalStringPackerPrefixer.sol";

uint256 constant NameFunction_selector = 0x06fdde0300000000000000000000000000000000000000000000000000000000;
uint256 constant UnknownNameQueryError_selector = 0xed3df7ad00000000000000000000000000000000000000000000000000000000;

contract StringPackerPrefixerTest is Test {
  Bytes32Metadata internal bytes32Metadata = new Bytes32Metadata();
  StringMetadata internal stringMetadata = new StringMetadata();
  ExternalStringPackerPrefixer internal lib =
    new ExternalStringPackerPrefixer();

  function testPrefixString(string memory prefix, string memory suffix)
    external
  {
    uint256 prefixLength;
    uint256 suffixLength;
    uint256 suffixBody;
    assembly {
      prefixLength := mload(prefix)
      suffixLength := mload(suffix)
      suffixBody := mload(add(suffix, 0x20))
    }
    vm.assume(
      prefixLength + suffixLength < 0x21
    );
    if (prefixLength == 0) {
      vm.expectRevert(StringPackerPrefixer.NullPrefix.selector);
      lib.prefixString(prefix, suffixLength, suffixBody);
      return;
    }

    string memory prefixed = lib.prefixString(prefix, suffixLength, suffixBody);
    assertTrue(
      keccak256(bytes(prefixed)) == keccak256(abi.encodePacked(prefix, suffix)),
      string(abi.encodePacked("prefixString returned bad output: ", prefixed))
    );
  }

  function testGetStringOrBytes32AsString_Bytes32() external {
    (uint256 size, uint256 value) = lib.getStringOrBytes32AsString(address(bytes32Metadata), NameFunction_selector, UnknownNameQueryError_selector);
    assertEq(size, 5);
    assertEq(value, 0x4d616b6572000000000000000000000000000000000000000000000000000000);
    (size, value) = lib.getStringOrBytes32AsString(address(stringMetadata), NameFunction_selector, UnknownNameQueryError_selector);
    assertEq(size, 5);
    assertEq(value, 0x4d616b6572000000000000000000000000000000000000000000000000000000);
  }

  function testPackUnpack() external {
    string memory str = "xDAI";
    bytes32 packed = lib.packString(str);
    string memory str2 = lib.unpackString(packed);
    assertEq(bytes(str), bytes(str2), "Unpacked string does not match original");
  }
}
