// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import "./libraries/LowGasSafeMath.sol";
import "./interfaces/IERC20.sol";

contract ERC20 is IERC20 {
  using LowGasSafeMath for uint256;

  mapping(address => uint256) public override balanceOf;

  mapping(address => mapping(address => uint256)) public override allowance;

  uint256 public override totalSupply;

  function transfer(address recipient, uint256 amount) external override returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function approve(address spender, uint256 amount) external override returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(
      sender,
      msg.sender,
      allowance[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance")
    );
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) external override returns (bool) {
    _approve(msg.sender, spender, allowance[msg.sender][spender].add(addedValue));
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) external override returns (bool) {
    _approve(
      msg.sender,
      spender,
      allowance[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero")
    );
    return true;
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");

    balanceOf[sender] = balanceOf[sender].sub(amount, "ERC20: transfer amount exceeds balance");
    balanceOf[recipient] = balanceOf[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount) internal {
    require(account != address(0), "ERC20: mint to the zero address");

    totalSupply = totalSupply.add(amount);
    balanceOf[account] = balanceOf[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount) internal {
    require(account != address(0), "ERC20: burn from the zero address");

    balanceOf[account] = balanceOf[account].sub(amount, "ERC20: burn amount exceeds balance");
    totalSupply = totalSupply.sub(amount);
    emit Transfer(account, address(0), amount);
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) internal {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    allowance[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _burnFrom(address account, uint256 amount) internal {
    _burn(account, amount);
    _approve(
      account,
      msg.sender,
      allowance[account][msg.sender].sub(amount, "ERC20: burn amount exceeds allowance")
    );
  }
}