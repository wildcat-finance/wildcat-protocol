// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import '../types/VaultStateCoder.sol';

// ============================== NOTICE ==============================
// This library was automatically generated with stackpacker.
// Be very careful about modifying it, as doing so incorrectly could
// result in corrupted reads/writes.
// ====================================================================

contract ExternalVaultStateCoder {
  VaultState internal _vaultState;

  function decode()
    external
    view
    returns (
      int256 annualInterestBips,
      uint256 scaledTotalSupply,
      uint256 scaleFactor,
      uint256 lastInterestAccruedTimestamp
    )
  {
    (
      annualInterestBips,
      scaledTotalSupply,
      scaleFactor,
      lastInterestAccruedTimestamp
    ) = VaultStateCoder.decode(_vaultState);
  }

  function encode(
    int256 annualInterestBips,
    uint256 scaledTotalSupply,
    uint256 scaleFactor,
    uint256 lastInterestAccruedTimestamp
  ) external {
    (_vaultState) = VaultStateCoder.encode(
      annualInterestBips,
      scaledTotalSupply,
      scaleFactor,
      lastInterestAccruedTimestamp
    );
  }

  function getNewScaleInputs()
    external
    view
    returns (
      int256 annualInterestBips,
      uint256 scaleFactor,
      uint256 lastInterestAccruedTimestamp
    )
  {
    (
      annualInterestBips,
      scaleFactor,
      lastInterestAccruedTimestamp
    ) = VaultStateCoder.getNewScaleInputs(
      _vaultState
    );
  }

  function setNewScaleOutputs(
    uint256 scaleFactor,
    uint256 lastInterestAccruedTimestamp
  ) external {
    (_vaultState) = VaultStateCoder
      .setNewScaleOutputs(
        _vaultState,
        scaleFactor,
        lastInterestAccruedTimestamp
      );
  }

  function getAnnualInterestBips()
    external
    view
    returns (int256 annualInterestBips)
  {
    (annualInterestBips) = VaultStateCoder
      .getAnnualInterestBips(_vaultState);
  }

  function setAnnualInterestBips(
    int256 annualInterestBips
  ) external {
    (_vaultState) = VaultStateCoder
      .setAnnualInterestBips(
        _vaultState,
        annualInterestBips
      );
  }

  function getScaledTotalSupply()
    external
    view
    returns (uint256 scaledTotalSupply)
  {
    (scaledTotalSupply) = VaultStateCoder
      .getScaledTotalSupply(_vaultState);
  }

  function setScaledTotalSupply(
    uint256 scaledTotalSupply
  ) external {
    (_vaultState) = VaultStateCoder
      .setScaledTotalSupply(
        _vaultState,
        scaledTotalSupply
      );
  }

  function getScaleFactor()
    external
    view
    returns (uint256 scaleFactor)
  {
    (scaleFactor) = VaultStateCoder
      .getScaleFactor(_vaultState);
  }

  function setScaleFactor(uint256 scaleFactor)
    external
  {
    (_vaultState) = VaultStateCoder
      .setScaleFactor(_vaultState, scaleFactor);
  }

  function getLastInterestAccruedTimestamp()
    external
    view
    returns (uint256 lastInterestAccruedTimestamp)
  {
    (
      lastInterestAccruedTimestamp
    ) = VaultStateCoder
      .getLastInterestAccruedTimestamp(
        _vaultState
      );
  }

  function setLastInterestAccruedTimestamp(
    uint256 lastInterestAccruedTimestamp
  ) external {
    (_vaultState) = VaultStateCoder
      .setLastInterestAccruedTimestamp(
        _vaultState,
        lastInterestAccruedTimestamp
      );
  }
}
