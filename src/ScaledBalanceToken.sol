// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { DefaultVaultState, VaultState, VaultStateCoder } from "./types/VaultStateCoder.sol";
import "./libraries/Math.sol";

uint256 constant SecondsIn365Days = 31536000;
uint256 constant RayBipsNumerator = 1e22;

abstract contract ScaledBalanceToken {
  using VaultStateCoder for VaultState;
  using Math for uint256;

  VaultState internal _state;
  mapping(address => uint256) public scaledBalanceOf;

  constructor(int256 _annualInterestBips) {
    _state = DefaultVaultState.setInitialState(_annualInterestBips, RayOne, block.timestamp);
  }

  /*//////////////////////////////////////////////////////////////
                          External Getters
  //////////////////////////////////////////////////////////////*/

  function balanceOf(address account) external view returns (uint256) {
    (uint256 scaleFactor, ) = _getCurrentScaleFactor(_state);
    return scaledBalanceOf[account].rayMul(scaleFactor);
  }

  function totalSupply() external view returns (uint256) {
    VaultState state = _state;
    (uint256 scaleFactor, ) = _getCurrentScaleFactor(state);
    return state.getScaledTotalSupply().rayMul(scaleFactor);
  }

  function getState()
    external
    view
    returns (
      int256 annualInterestBips,
      uint256 scaledTotalSupply,
      uint256 scaleFactor,
      uint256 lastInterestAccruedTimestamp
    )
  {
    return _state.decode();
  }

  function maxTotalSupply() public view virtual returns (uint256);

  /*//////////////////////////////////////////////////////////////
                       Internal State Handlers
  //////////////////////////////////////////////////////////////*/

  function _getUpdatedScaleFactor() internal returns (uint256) {
    VaultState state = _state;
    (uint256 scaleFactor, bool changed) = _getCurrentScaleFactor(state);
    if (changed) {
      _state = state.setNewScaleOutputs(scaleFactor, block.timestamp);
    }
    return scaleFactor;
  }

  function _getCurrentState() internal view returns (VaultState state) {
    (uint256 scaleFactor, bool changed) = _getCurrentScaleFactor(state);
    if (changed) {
      state = state.setNewScaleOutputs(scaleFactor, block.timestamp);
    }
  }

  function _getCurrentScaleFactor(VaultState state)
    internal
    view
    returns (
      uint256, /* newScaleFactor */
      bool /* changed */
    )
  {
    (
      int256 annualInterestBips,
      uint256 scaleFactor,
      uint256 lastInterestAccruedTimestamp
    ) = state.getNewScaleInputs();
    uint256 timeElapsed;
    unchecked {
      timeElapsed = block.timestamp - lastInterestAccruedTimestamp;
    }
    bool changed = timeElapsed > 0;
    if (changed) {
      int256 newInterest;
      assembly {
        // Convert annual bips to fraction of 1e26 - (bips * 1e22) / 31536000
        // Multiply by 1e22 = multiply by 1e26 and divide by 10000
        let interestPerSecond := sdiv(
          mul(annualInterestBips, RayBipsNumerator),
          SecondsIn365Days
        )
        // Calculate interest accrued since last update
        newInterest := mul(timeElapsed, interestPerSecond)
      }
      // Calculate change to scale factor
      int256 scaleFactorChange = scaleFactor.rayMul(newInterest);
      assembly {
        scaleFactor := add(scaleFactor, scaleFactorChange)
        // Total scaleFactor must not underflow
        if slt(scaleFactor, 0) {
          mstore(0, Panic_error_signature)
          mstore(Panic_error_offset, Panic_arithmetic)
          revert(0, Panic_error_length)
        }
      }
    }
    return (scaleFactor, changed);
  }

  /*//////////////////////////////////////////////////////////////
                            ERC20 Actions
  //////////////////////////////////////////////////////////////*/

  function _beforeMint(
    address to,
    uint256 amount,
    uint256 scaledAmount
  ) internal virtual {}

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal {
    uint256 scaleFactor = _getUpdatedScaleFactor();
    uint256 scaledAmount = amount.rayDiv(scaleFactor);
    scaledBalanceOf[from] -= scaledAmount;
    unchecked {
      scaledBalanceOf[to] += scaledAmount;
    }
  }

  function _getMaximumDeposit(VaultState state, uint256 scaleFactor)
    internal
    view
    returns (uint256)
  {
    uint256 _totalSupply = state.getScaledTotalSupply().rayMul(scaleFactor);
    uint256 _maxTotalSupply = maxTotalSupply();
    return _maxTotalSupply.subMinZero(_totalSupply);
  }

  function _mintUpTo(address to, uint256 amount)
    internal
    returns (uint256 actualAmount)
  {
    VaultState state = _getCurrentState();
    (uint256 scaleFactor, ) = _getCurrentScaleFactor(state);
    actualAmount = Math.min(amount, _getMaximumDeposit(state, scaleFactor));
    uint256 scaledAmount = actualAmount.rayDiv(scaleFactor);
    _beforeMint(to, amount, scaledAmount);
    scaledBalanceOf[to] += scaledAmount;
    unchecked {
      // If user's balance did not overflow uint256, neither will totalSupply
      // Coder checks for overflow of uint96
      state.setScaledTotalSupply(
        state.getScaledTotalSupply() + scaledAmount
      );
    }
    _state = state;
  }

  // function _mint(address to, uint256 amount) internal {
  //   VaultState state = _getCurrentState();
  //   (uint256 scaleFactor, ) = _getCurrentScaleFactor(state);
  //   uint256 scaledAmount = amount.rayDiv(scaleFactor);
  //   scaledBalanceOf[to] += scaledAmount;
  //   unchecked {
  //     // If user's balance did not overflow uint256, neither will totalSupply
  //     // Coder checks for overflow of uint96
  //     state.setScaledTotalSupply(
  //       state.getScaledTotalSupply() + scaledAmount
  //     );
  //   }
  //   _state = state;
  // }

  function _burn(address account, uint256 amount) internal {
    VaultState state = _getCurrentState();
    (uint256 scaleFactor, ) = _getCurrentScaleFactor(state);
    uint256 scaledAmount = amount.rayDiv(scaleFactor);
    scaledBalanceOf[account] -= scaledAmount;
    unchecked {
      // If user's balance did not underflow uint256, neither will totalSupply
      state.setScaledTotalSupply(
        state.getScaledTotalSupply() - scaledAmount
      );
    }
    _state = state;
  }
}
