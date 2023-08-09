// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'reference/libraries/FIFOQueue.sol';
import 'forge-std/Test.sol';

contract FIFOQueueTest is Test {
	FIFOQueue internal arr;

	function _shift() external {
		arr.shift();
	}

	function _first() external view returns (uint32) {
		return arr.first();
	}

	function _get(uint256 index) external view returns (uint32) {
		return arr.at(index);
	}

	function _shiftN(uint128 n) external {
		arr.shiftN(n);
	}

	function test() external {
		arr.push(1);
		arr.push(2);
		arr.push(3);
		arr.shift();
		arr.push(4);
		arr.shiftN(2);
		assertEq(arr.length(), 1);
		assertEq(arr.first(), 4);
		assertEq(arr.at(0), 4);
	}

	function test_push() external {
		assertEq(arr.length(), 0);
		arr.push(1);
		assertEq(arr.length(), 1);
		assertEq(arr.first(), 1);
		assertEq(arr.at(0), 1);
		assertEq(arr.startIndex, 0);
		assertEq(arr.nextIndex, 1);
	}

	function test_shift() external {
		arr.push(1);
		arr.shift();
		assertEq(arr.startIndex, 1);
		assertEq(arr.nextIndex, 1);
	}

	function test_shift_OutOfBounds() external {
		arr.push(1);
		arr.shift();
		assertEq(arr.startIndex, 1);
		assertEq(arr.nextIndex, 1);
	}

	function test_shiftN() external {
		arr.push(1);
		arr.push(1);
		arr.push(1);
		arr.shiftN(2);
		assertEq(arr.length(), 1);
		assertEq(arr.startIndex, 2);
		assertEq(arr.nextIndex, 3);
	}

	function test_shiftN_OutOfBounds() external {
		arr.push(1);
		vm.expectRevert(FIFOQueueLib.FIFOQueueOutOfBounds.selector);
		this._shiftN(2);
	}

	function test_first() external {
		arr.push(1);
		assertEq(arr.first(), 1);
	}

	function test_first_OutOfBounds() external {
		vm.expectRevert(FIFOQueueLib.FIFOQueueOutOfBounds.selector);
		this._first();
	}

	function test_get() external {
		arr.push(1);
		assertEq(arr.at(0), 1);
    arr.push(2);
    arr.shift();
    assertEq(arr.at(0), 2);
	}

	function test_get_OutOfBounds() external {
		vm.expectRevert(FIFOQueueLib.FIFOQueueOutOfBounds.selector);
		this._get(0);
	}

  function assertEq(uint32[] memory a, uint32[] memory b) internal {
    assertEq(a.length, b.length, "length");
    for (uint256 i = 0; i < a.length; i++) {
      assertEq(a[i], b[i]);
    }
  }

  function test_values() external {
    assertEq(arr.values().length, 0);
    uint32[] memory _arr = new uint32[](3);
    _arr[0] = 1;
    _arr[1] = 2;
    _arr[2] = 3;
    arr.push(1);
    arr.push(2);
    arr.push(3);
    assertEq(arr.values(), _arr);
  }
}
