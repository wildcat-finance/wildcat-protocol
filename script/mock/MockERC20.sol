// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.17;

import {MockERC20 as SolmateMockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract MockERC20 is SolmateMockERC20 {
    constructor(string memory _name, string memory _symbol) SolmateMockERC20(_name, _symbol, 18) {}

    bool public constant isMock = true;

    function faucet() external {
        mint(msg.sender, 100e18);
    }
}
