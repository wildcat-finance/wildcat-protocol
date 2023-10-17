// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import './WildcatMarketBase.sol';

contract WildcatMarketToken is WildcatMarketBase {
  using SafeCastLib for uint256;

  /* -------------------------------------------------------------------------- */
  /*                                ERC20 Queries                               */
  /* -------------------------------------------------------------------------- */

  mapping(address => mapping(address => uint256)) public allowance;

  /// @notice Returns the normalized balance of `account` with interest.
  function balanceOf(address account) public view virtual nonReentrantView returns (uint256) {
    (MarketState memory state, , ) = _calculateCurrentState();
    return state.normalizeAmount(_accounts[account].scaledBalance);
  }

  /// @notice Returns the normalized total supply with interest.
  function totalSupply() external view virtual nonReentrantView returns (uint256) {
    (MarketState memory state, , ) = _calculateCurrentState();
    return state.totalSupply();
  }

  /* -------------------------------------------------------------------------- */
  /*                                ERC20 Actions                               */
  /* -------------------------------------------------------------------------- */

  function approve(address spender, uint256 amount) external virtual nonReentrant returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function transfer(address to, uint256 amount) external virtual nonReentrant returns (bool) {
    _transfer(msg.sender, to, amount);
    return true;
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) external virtual nonReentrant returns (bool) {
    uint256 allowed = allowance[from][msg.sender];

    // Saves gas for unlimited approvals.
    if (allowed != type(uint256).max) {
      uint256 newAllowance = allowed - amount;
      _approve(from, msg.sender, newAllowance);
    }

    _transfer(from, to, amount);

    return true;
  }

  function _approve(address approver, address spender, uint256 amount) internal virtual {
    allowance[approver][spender] = amount;
    emit Approval(approver, spender, amount);
  }

  function _transfer(address from, address to, uint256 amount) internal virtual {
    MarketState memory state = _getUpdatedState();
    uint104 scaledAmount = state.scaleAmount(amount).toUint104();

    if (scaledAmount == 0) {
      revert NullTransferAmount();
    }

    Account memory fromAccount = _getAccount(from);
    fromAccount.scaledBalance -= scaledAmount;
    _accounts[from] = fromAccount;

    Account memory toAccount = _getAccount(to);
    toAccount.scaledBalance += scaledAmount;
    _accounts[to] = toAccount;

    _writeState(state);
    emit Transfer(from, to, amount);
  }
}
