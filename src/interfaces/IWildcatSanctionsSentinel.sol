// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IWildcatSanctionsSentinel {
  event NewSanctionsEscrow(address borrower, address account, address asset);

  error NotRegisteredVault();

  // Returns immutable sanctions list contract
  function chainalysisSanctionsList() external view returns (address);

  // Returns immutable arch-controller
  function archController() external view returns (address);

  // Returns result of `chainalysisSanctionsList().isSanctioned(account)`
  function isSanctioned(address account) external view returns (bool);

  // Returns create2 address of sanctions escrow contract for
  // combination of `account,borrower,asset`
  function getEscrowAddress(
    address account,
    address borrower,
    address asset
  ) external view returns (address escrowContract);

  /**
   * @dev Returns a create2 deployment of WildcatSanctionsEscrow unique to each
   *      combination of `account,borrower,asset`. If the contract is already
   *      deployed, returns the existing address.
   *
   *      Emits `NewSanctionsEscrow(borrower, account, asset)` if a new contract
   *      is deployed.
   *
   *      If `archController.isRegisteredVault(msg.sender)` returns false,
   *      reverts with `NotRegisteredVault`.
   *
   *      The sanctions escrow contract is used to hold assets until either the
   *      sanctioned status is lifted or the assets are released by the borrower.
   */
  function createEscrow(
    address account,
    address borrower,
    address asset
  ) external returns (address escrowContract);
}
