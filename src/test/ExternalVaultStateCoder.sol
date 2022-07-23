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
      uint256 collateralizationRatioBips,
      int256 annualInterestBips,
      uint256 totalSupply,
      uint256 scaleFactor,
      uint256 lastInterestAccruedTimestamp
    )
  {
    (
      collateralizationRatioBips,
      annualInterestBips,
      totalSupply,
      scaleFactor,
      lastInterestAccruedTimestamp
    ) = VaultStateCoder.decode(_vaultState);
  }

  function encode(
    uint256 collateralizationRatioBips,
    int256 annualInterestBips,
    uint256 totalSupply,
    uint256 scaleFactor,
    uint256 lastInterestAccruedTimestamp
  ) external {
    (_vaultState) = VaultStateCoder.encode(
      collateralizationRatioBips,
      annualInterestBips,
      totalSupply,
      scaleFactor,
      lastInterestAccruedTimestamp
    );
  }

  function getCollateralizationRatioBips()
    external
    view
    returns (uint256 collateralizationRatioBips)
  {
    (collateralizationRatioBips) = VaultStateCoder
      .getCollateralizationRatioBips(_vaultState);
  }

  function setCollateralizationRatioBips(
    uint256 collateralizationRatioBips
  ) external {
    (_vaultState) = VaultStateCoder
      .setCollateralizationRatioBips(
        _vaultState,
        collateralizationRatioBips
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

  function getTotalSupply()
    external
    view
    returns (uint256 totalSupply)
  {
    (totalSupply) = VaultStateCoder
      .getTotalSupply(_vaultState);
  }

  function setTotalSupply(uint256 totalSupply)
    external
  {
    (_vaultState) = VaultStateCoder
      .setTotalSupply(_vaultState, totalSupply);
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
