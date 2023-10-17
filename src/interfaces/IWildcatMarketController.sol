// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import './WildcatStructsAndEnums.sol';
import './IWildcatMarketControllerEventsAndErrors.sol';

interface IWildcatMarketController is IWildcatMarketControllerEventsAndErrors {
  // Returns immutable controller factory
  function controllerFactory() external view returns (address);

  // Returns immutable market factory
  function marketFactory() external view returns (address);

  // Returns immutable arch-controller
  function archController() external view returns (address);

  // Returns immutable borrower address
  function borrower() external view returns (address);

  /**
   * @dev Returns immutable protocol fee configuration for new markets.
   *      Queried from the controller factory.
   *
   * @return feeRecipient         feeRecipient to use in new markets
   * @return protocolFeeBips      protocolFeeBips to use in new markets
   * @return originationFeeAsset  Asset used to pay fees for new market
   *                              deployments
   * @return originationFeeAmount Amount of originationFeeAsset paid
   *                              for new market deployments
   */
  function getProtocolFeeConfiguration()
    external
    view
    returns (
      address feeRecipient,
      uint16 protocolFeeBips,
      address originationFeeAsset,
      uint256 originationFeeAmount
    );

  /**
   * @dev Returns immutable constraints on market parameters that
   *      the controller will enforce.
   */
  function getParameterConstraints()
    external
    view
    returns (MarketParameterConstraints memory constraints);

  /* -------------------------------------------------------------------------- */
  /*                               Lender Registry                              */
  /* -------------------------------------------------------------------------- */

  function getAuthorizedLenders() external view returns (address[] memory);

  function getAuthorizedLenders(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory);

  function getAuthorizedLendersCount() external view returns (uint256);

  function isAuthorizedLender(address lender) external view returns (bool);

  /**
   * @dev Grant authorization for a set of lenders.
   *
   *      Note: Only updates the internal set of approved lenders.
   *      Must call `updateLenderAuthorization` to apply changes
   *      to existing market accounts
   */
  function authorizeLenders(address[] memory lenders) external;

  /**
   * @dev Revoke authorization for a set of lenders.
   *
   *      Note: Only updates the internal set of approved lenders.
   *      Must call `updateLenderAuthorization` to apply changes
   *      to existing market accounts
   */
  function deauthorizeLenders(address[] memory lenders) external;

  /**
   * @dev Update lender authorization for a set of markets to the current
   *      status.
   */
  function updateLenderAuthorization(address lender, address[] memory markets) external;

  /* -------------------------------------------------------------------------- */
  /*                               Market Controls                               */
  /* -------------------------------------------------------------------------- */

  /**
   * @dev Modify the interest rate for a market.
   * If the new interest rate is lower than the current interest rate,
   * the reserve ratio is set to 90% for the next two weeks.
   */
  function setAnnualInterestBips(address market, uint16 annualInterestBips) external;

  /**
   * @dev Reset the reserve ratio to the value it had prior to
   *      a call to `setAnnualInterestBips`.
   */
  function resetReserveRatio(address market) external;

  function temporaryExcessReserveRatio(
    address
  ) external view returns (uint128 reserveRatioBips, uint128 expiry);

  /**
   * @dev Deploys a new instance of the market through the market factory
   *      and registers it with the arch-controller.
   *
   *      If `msg.sender` is not `borrower` or `controllerFactory`,
   *      reverts with `CallerNotBorrowerOrControllerFactory`.
   *
   *	    If `msg.sender == borrower && !archController.isRegisteredBorrower(msg.sender)`,
   *		  reverts with `NotRegisteredBorrower`.
   *
   *      If called by `controllerFactory`, skips borrower check.
   *
   *      If `originationFeeAmount` returned by controller factory is not zero,
   *      transfers `originationFeeAmount` of `originationFeeAsset` from
   *      `msg.sender` to `feeRecipient`.
   */
  function deployMarket(
    address asset,
    string memory namePrefix,
    string memory symbolPrefix,
    uint128 maxTotalSupply,
    uint16 annualInterestBips,
    uint16 delinquencyFeeBips,
    uint32 withdrawalBatchDuration,
    uint16 reserveRatioBips,
    uint32 delinquencyGracePeriod
  ) external returns (address);

  function getMarketParameters() external view returns (MarketParameters memory);
}
