// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20;

interface IWildcatMarketControllerEventsAndErrors {
  // ========================================================================== //
  //                                   Errors                                   //
  // ========================================================================== //

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

  // Error thrown when `deployMarket` is called for an underlying asset which has
  // been blacklisted by the arch-controller owner.
  error UnderlyingNotPermitted();

  // Error thrown if borrower calls `deployMarket` and is no longer
  // registered with the arch-controller.
  error NotRegisteredBorrower();

  error EmptyString();

  error NotControlledMarket();

  error MarketAlreadyDeployed();

  error ExcessReserveRatioStillActive();

  error CapacityChangeOnClosedMarket();

  error AprChangeOnClosedMarket();

  error AprChangeNotPending();

  error MarketAlreadyClosed();

  error UnknownNameQueryError();

  error UnknownSymbolQueryError();

  // ========================================================================== //
  //                                   Events                                   //
  // ========================================================================== //

  event LenderAuthorized(address);

  event LenderDeauthorized(address);

  event MarketDeployed(
    address indexed market,
    string name,
    string symbol,
    address asset,
    uint256 maxTotalSupply,
    uint256 annualInterestBips,
    uint256 delinquencyFeeBips,
    uint256 withdrawalBatchDuration,
    uint256 reserveRatioBips,
    uint256 delinquencyGracePeriod
  );

  event TemporaryExcessReserveRatioActivated(
    address indexed market,
    uint256 originalReserveRatioBips,
    uint256 temporaryReserveRatioBips,
    uint256 temporaryReserveRatioExpiry
  );

  event TemporaryExcessReserveRatioUpdated(
    address indexed market,
    uint256 originalReserveRatioBips,
    uint256 temporaryReserveRatioBips,
    uint256 temporaryReserveRatioExpiry
  );

  event TemporaryExcessReserveRatioCanceled(address indexed market);

  event TemporaryExcessReserveRatioExpired(address indexed market);
}
