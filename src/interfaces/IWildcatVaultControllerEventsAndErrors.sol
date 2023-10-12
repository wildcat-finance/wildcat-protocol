// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IWildcatVaultControllerEventsAndErrors {
  /* -------------------------------------------------------------------------- */
  /*                                   Errors                                   */
  /* -------------------------------------------------------------------------- */

  error DelinquencyGracePeriodOutOfBounds();
  error ReserveRatioBipsOutOfBounds();
  error DelinquencyFeeBipsOutOfBounds();
  error WithdrawalBatchDurationOutOfBounds();
  error AnnualInterestBipsOutOfBounds();

  // Error thrown when a borrower-only method is called by another account.
  error CallerNotBorrower();

  // Error thrown when `deployVault` called by an account other than `borrower` or
  // `controllerFactory`.
  error CallerNotBorrowerOrControllerFactory();

  // Error thrown if borrower calls `deployVault` and is no longer
  // registered with the arch-controller.
  error NotRegisteredBorrower();

  error EmptyString();

  error NotControlledVault();

  error VaultAlreadyDeployed();

  error ExcessReserveRatioStillActive();
  error AprChangeNotPending();

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event LenderAuthorized(address);

  event LenderDeauthorized(address);

  event VaultDeployed(address indexed vault);
}
