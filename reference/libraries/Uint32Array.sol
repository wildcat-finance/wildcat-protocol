// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct Uint32Array {
	uint128 len;
	uint128 startIndex;
	mapping(uint256 => uint32) data;
}

// @todo - make tightly packed

using Uint32ArrayLib for Uint32Array global;

error Uint32ArrayOutOfBounds(uint256 index, uint256 length);

library Uint32ArrayLib {
	function push(Uint32Array storage arr, uint32 value) internal {
		uint128 len = arr.len;
		arr.data[len] = value;
		arr.len = len + 1;
	}

  function isEmpty(Uint32Array storage arr) internal view returns (bool) {
    return arr.len == arr.startIndex;
  }

	function first(Uint32Array storage arr) internal view returns (uint32) {
		return arr.data[arr.startIndex];
	}

	function get(Uint32Array storage arr, uint256 index) internal view returns (uint32) {
		return arr.data[index];
	}

	function shift(Uint32Array storage arr) internal {
		uint128 startIndex = arr.startIndex;
		delete arr.data[startIndex];
		arr.startIndex = startIndex + 1;
	}

	function length(Uint32Array storage arr) internal view returns (uint128) {
		return arr.len - arr.startIndex;
	}
}
