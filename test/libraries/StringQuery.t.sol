// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'forge-std/Test.sol';
import 'src/libraries/StringQuery.sol';

contract Bytes32Metadata {
  bytes32 public constant name = 'TestA';
  bytes32 public constant symbol = 'TestA';
}

contract StringMetadata {
  string public name = 'TestB';
  string public symbol = 'TestB';
}

contract BadStrings {
  bool giveRevertData;

  function setGiveRevertData(bool _giveRevertData) external {
    giveRevertData = _giveRevertData;
  }

  function name() external {
    if (giveRevertData) {
      revert('name');
    } else {
      revert();
    }
  }
}

contract StringQueryTest is Test {
  Bytes32Metadata internal immutable bytes32Metadata = new Bytes32Metadata();
  StringMetadata internal immutable stringMetadata = new StringMetadata();
  BadStrings internal immutable badStrings = new BadStrings();

  function queryName(address token) external view returns (string memory) {
    return queryName(token);
  }

  function querySymbol(address token) external view returns (string memory) {
    return querySymbol(token);
  }

  function test_queryName() external {
    assertEq(queryName(address(bytes32Metadata)), 'TestA');
    assertEq(queryName(address(stringMetadata)), 'TestB');

    vm.expectRevert(bytes4(bytes32(UnknownNameQueryError_selector)));
    this.queryName(address(badStrings));

    badStrings.setGiveRevertData(true);
    vm.expectRevert(bytes('name'));
    this.queryName(address(badStrings));
  }

  function test_querySymbol() external {
    assertEq(querySymbol(address(bytes32Metadata)), 'TestA');
    assertEq(querySymbol(address(stringMetadata)), 'TestB');
  }
}
