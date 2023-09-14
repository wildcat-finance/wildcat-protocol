// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/**
 * @title ReentrancyGuard
 * @author 0age
 *         https://github.com/ProjectOpenSea/seaport/blob/main/contracts/lib/ReentrancyGuard.sol
 * Changes: add modifier, bring constants & error definition into contract
 * @notice ReentrancyGuard contains a storage variable and related functionality
 *         for protecting against reentrancy.
 */
contract ReentrancyGuard {
  /**
   * @dev Revert with an error when a caller attempts to reenter a protected
   *      function.
   */
  error NoReentrantCalls();

  // Prevent reentrant calls on protected functions.
  uint256 private _reentrancyGuard;

  uint256 private constant _NOT_ENTERED = 1;
  uint256 private constant _ENTERED = 2;

  /**
   * @dev Reentrancy guard for state-changing functions.
   *      Reverts if the reentrancy guard is currently set; otherwise, sets
   *      the reentrancy guard, executes the function body, then clears the
   *      reentrancy guard.
   */
  modifier nonReentrant() {
    _setReentrancyGuard();
    _;
    _clearReentrancyGuard();
  }

  /**
   * @dev Reentrancy guard for view functions.
   *      Reverts if the reentrancy guard is currently set.
   */
  modifier nonReentrantView() {
    _assertNonReentrant();
    _;
  }

  /**
   * @dev Initialize the reentrancy guard during deployment.
   */
  constructor() {
    // Initialize the reentrancy guard in a cleared state.
    _reentrancyGuard = _NOT_ENTERED;
  }

  /**
   * @dev Internal function to ensure that a sentinel value for the reentrancy
   *      guard is not currently set and, if not, to set a sentinel value for
   *      the reentrancy guard.
   */
  function _setReentrancyGuard() internal {
    // Ensure that the reentrancy guard is not already set.
    _assertNonReentrant();

    // Set the reentrancy guard.
    unchecked {
      _reentrancyGuard = _ENTERED;
    }
  }

  /**
   * @dev Internal function to unset the reentrancy guard sentinel value.
   */
  function _clearReentrancyGuard() internal {
    // Clear the reentrancy guard.
    _reentrancyGuard = _NOT_ENTERED;
  }

  /**
   * @dev Internal view function to ensure that a sentinel value for the
   *         reentrancy guard is not currently set.
   */
  function _assertNonReentrant() internal view {
    // Ensure that the reentrancy guard is not currently set.
    if (_reentrancyGuard != _NOT_ENTERED) {
      revert NoReentrantCalls();
    }
  }
}
