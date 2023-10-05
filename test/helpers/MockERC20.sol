// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { ERC20 } from 'solmate/tokens/ERC20.sol';

contract MockERC20 is ERC20 {
  constructor() ERC20('MockERC20', 'MERC', 18) {}

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }
}
