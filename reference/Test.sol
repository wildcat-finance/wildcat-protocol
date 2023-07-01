
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

contract Test {
	function f1(uint _expiry, uint _timestamp) internal pure returns (bool) {
		return _expiry != 0 && _expiry <= _timestamp;
	}
	function f2(uint _expiry, uint _timestamp) internal pure returns (bool result) {
    unchecked {
      result = _timestamp > _expiry - 1;
    }
	}

	function f(uint _expiry, uint _timestamp) public pure {
    assert(
      f1(_expiry, _timestamp) == f2(_expiry, _timestamp)
    );
	}
}