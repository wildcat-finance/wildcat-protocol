// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IWildcatMarketControllerEventsAndErrors {
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

  // Error thrown when `deployMarket` called by an account other than `borrower` or
  // `controllerFactory`.
  error CallerNotBorrowerOrControllerFactory();

  // Error thrown if borrower calls `deployMarket` and is no longer
  // registered with the arch-controller.
  error NotRegisteredBorrower();

  error EmptyString();

  error NotControlledMarket();

  error MarketAlreadyDeployed();

  error ExcessReserveRatioStillActive();
  error AprChangeNotPending();

  /* -------------------------------------------------------------------------- */
  /*                                   Events                                   */
  /* -------------------------------------------------------------------------- */

  event LenderAuthorized(address);

  event LenderDeauthorized(address);

  event MarketDeployed(address indexed market);
}
