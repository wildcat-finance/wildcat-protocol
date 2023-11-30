// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { EnumerableSet } from 'openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import 'solady/utils/SafeTransferLib.sol';
import './market/WildcatMarket.sol';
import './interfaces/IWildcatArchController.sol';
import './interfaces/IWildcatMarketControllerEventsAndErrors.sol';
import './interfaces/IWildcatMarketControllerFactory.sol';
import './libraries/LibStoredInitCode.sol';
import './libraries/MathUtils.sol';
import { queryName, querySymbol } from './libraries/StringQuery.sol';
import './spherex/SphereXProtectedRegisteredBase.sol';

struct TemporaryReserveRatio {
  uint16 originalAnnualInterestBips;
  uint16 originalReserveRatioBips;
  uint32 expiry;
}

struct TmpMarketParameterStorage {
  address asset;
  string name;
  string symbol;
  address feeRecipient;
  uint16 protocolFeeBips;
  uint128 maxTotalSupply;
  uint16 annualInterestBips;
  uint16 delinquencyFeeBips;
  uint32 withdrawalBatchDuration;
  uint16 reserveRatioBips;
  uint32 delinquencyGracePeriod;
}

contract WildcatMarketController is SphereXProtectedRegisteredBase, IWildcatMarketController {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeCastLib for uint256;
  using SafeTransferLib for address;

  // ========================================================================== //
  //                                 Immutables                                 //
  // ========================================================================== //

  function archController() external view override returns (address) {
    return _archController;
  }

  address public immutable override controllerFactory;

  address public immutable override borrower;

  address public immutable override sentinel;

  address public immutable override marketInitCodeStorage;

  uint256 public immutable override marketInitCodeHash;

  uint256 internal immutable ownCreate2Prefix = LibStoredInitCode.getCreate2Prefix(address(this));

  uint32 internal immutable MinimumDelinquencyGracePeriod;
  uint32 internal immutable MaximumDelinquencyGracePeriod;

  uint16 internal immutable MinimumReserveRatioBips;
  uint16 internal immutable MaximumReserveRatioBips;

  uint16 internal immutable MinimumDelinquencyFeeBips;
  uint16 internal immutable MaximumDelinquencyFeeBips;

  uint32 internal immutable MinimumWithdrawalBatchDuration;
  uint32 internal immutable MaximumWithdrawalBatchDuration;

  uint16 internal immutable MinimumAnnualInterestBips;
  uint16 internal immutable MaximumAnnualInterestBips;

  // ========================================================================== //
  //                                   Storage                                  //
  // ========================================================================== //

  EnumerableSet.AddressSet internal _authorizedLenders;

  EnumerableSet.AddressSet internal _controlledMarkets;

  /// @dev Temporary storage for market parameters, used during market deployment
  TmpMarketParameterStorage internal _tmpMarketParameters;

  mapping(address => TemporaryReserveRatio) public override temporaryExcessReserveRatio;

  // ========================================================================== //
  //                                 Constructor                                //
  // ========================================================================== //

  constructor() {
    controllerFactory = msg.sender;
    MarketControllerParameters memory parameters = IWildcatMarketControllerFactory(msg.sender)
      .getMarketControllerParameters();
    _archController = parameters.archController;
    borrower = parameters.borrower;
    sentinel = parameters.sentinel;
    marketInitCodeStorage = parameters.marketInitCodeStorage;
    marketInitCodeHash = parameters.marketInitCodeHash;
    MinimumDelinquencyGracePeriod = parameters.minimumDelinquencyGracePeriod;
    MaximumDelinquencyGracePeriod = parameters.maximumDelinquencyGracePeriod;
    MinimumReserveRatioBips = parameters.minimumReserveRatioBips;
    MaximumReserveRatioBips = parameters.maximumReserveRatioBips;
    MinimumDelinquencyFeeBips = parameters.minimumDelinquencyFeeBips;
    MaximumDelinquencyFeeBips = parameters.maximumDelinquencyFeeBips;
    MinimumWithdrawalBatchDuration = parameters.minimumWithdrawalBatchDuration;
    MaximumWithdrawalBatchDuration = parameters.maximumWithdrawalBatchDuration;
    MinimumAnnualInterestBips = parameters.minimumAnnualInterestBips;
    MaximumAnnualInterestBips = parameters.maximumAnnualInterestBips;
    __SphereXProtectedRegisteredBase_init(parameters.sphereXEngine);
  }

  // ========================================================================== //
  //                                  Modifiers                                 //
  // ========================================================================== //

  modifier onlyBorrower() {
    if (msg.sender != borrower) {
      revert CallerNotBorrower();
    }
    _;
  }

  modifier onlyControlledMarket(address market) {
    if (!_controlledMarkets.contains(market)) {
      revert NotControlledMarket();
    }
    _;
  }

  // ========================================================================== //
  //                        Controller Parameter Queries                        //
  // ========================================================================== //

  /**
   * @dev Returns immutable protocol fee configuration for new markets.
   *      Queried from the controller factory.
   *
   * @return feeRecipient         feeRecipient to use in new markets
   * @return originationFeeAsset  Asset used to pay fees for new market
   *                              deployments
   * @return originationFeeAmount Amount of originationFeeAsset paid
   *                              for new market deployments
   * @return protocolFeeBips      protocolFeeBips to use in new markets
   */
  function getProtocolFeeConfiguration()
    external
    view
    override
    returns (
      address feeRecipient,
      address originationFeeAsset,
      uint80 originationFeeAmount,
      uint16 protocolFeeBips
    )
  {
    return IWildcatMarketControllerFactory(controllerFactory).getProtocolFeeConfiguration();
  }

  /**
   * @dev Returns immutable constraints on market parameters that
   *      the controller variant will enforce.
   */
  function getParameterConstraints()
    external
    view
    override
    returns (MarketParameterConstraints memory constraints)
  {
    constraints.minimumDelinquencyGracePeriod = MinimumDelinquencyGracePeriod;
    constraints.maximumDelinquencyGracePeriod = MaximumDelinquencyGracePeriod;
    constraints.minimumReserveRatioBips = MinimumReserveRatioBips;
    constraints.maximumReserveRatioBips = MaximumReserveRatioBips;
    constraints.minimumDelinquencyFeeBips = MinimumDelinquencyFeeBips;
    constraints.maximumDelinquencyFeeBips = MaximumDelinquencyFeeBips;
    constraints.minimumWithdrawalBatchDuration = MinimumWithdrawalBatchDuration;
    constraints.maximumWithdrawalBatchDuration = MaximumWithdrawalBatchDuration;
    constraints.minimumAnnualInterestBips = MinimumAnnualInterestBips;
    constraints.maximumAnnualInterestBips = MaximumAnnualInterestBips;
  }

  // ========================================================================== //
  //                               Lender Registry                              //
  // ========================================================================== //

  /**
   * @dev Returns the set of authorized lenders.
   */
  function getAuthorizedLenders() external view override returns (address[] memory) {
    return _authorizedLenders.values();
  }

  function getAuthorizedLenders(
    uint256 start,
    uint256 end
  ) external view override returns (address[] memory arr) {
    uint256 len = _authorizedLenders.length();
    end = MathUtils.min(end, len);
    uint256 count = end - start;
    arr = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      arr[i] = _authorizedLenders.at(start + i);
    }
  }

  function getAuthorizedLendersCount() external view override returns (uint256) {
    return _authorizedLenders.length();
  }

  function isAuthorizedLender(address lender) external view virtual override returns (bool) {
    return _authorizedLenders.contains(lender);
  }

  /**
   * @dev Grant authorization for a set of lenders.
   *
   *      Note: Only updates the internal set of approved lenders.
   *      Must call `updateLenderAuthorization` to apply changes
   *      to existing market accounts
   */
  function authorizeLenders(
    address[] memory lenders
  ) external override onlyBorrower sphereXGuardExternal {
    for (uint256 i = 0; i < lenders.length; i++) {
      address lender = lenders[i];
      if (_authorizedLenders.add(lender)) {
        emit LenderAuthorized(lender);
      }
    }
  }

  /**
   * @dev Grant authorization for a set of lenders and update their authorization
   *      status for a set of markets.
   */
  function authorizeLendersAndUpdateMarkets(
    address[] memory lenders,
    address[] memory markets
  ) external override onlyBorrower sphereXGuardExternal {
    for (uint256 i = 0; i < lenders.length; i++) {
      address lender = lenders[i];
      if (_authorizedLenders.add(lender)) {
        emit LenderAuthorized(lender);
      }
    }

    bytes memory data = abi.encodeWithSelector(
      WildcatMarketConfig.updateAccountAuthorizations.selector,
      lenders,
      true
    );
    for (uint256 i = 0; i < markets.length; i++) {
      address market = markets[i];
      if (!_controlledMarkets.contains(market)) {
        revert NotControlledMarket();
      }
      assembly {
        let success := call(gas(), market, 0, add(data, 0x20), mload(data), 0, 0)
        if iszero(success) {
          returndatacopy(0, 0, returndatasize())
          revert(0, returndatasize())
        }
      }
    }
  }

  /**
   * @dev Revoke authorization for a set of lenders and update their authorization
   *      status for a set of markets.
   */
  function deauthorizeLendersAndUpdateMarkets(
    address[] memory lenders,
    address[] memory markets
  ) external override onlyBorrower sphereXGuardExternal {
    for (uint256 i = 0; i < lenders.length; i++) {
      address lender = lenders[i];
      if (_authorizedLenders.remove(lender)) {
        emit LenderDeauthorized(lender);
      }
    }
    bytes memory data = abi.encodeWithSelector(
      WildcatMarketConfig.updateAccountAuthorizations.selector,
      lenders,
      false
    );
    for (uint256 i = 0; i < markets.length; i++) {
      address market = markets[i];
      if (!_controlledMarkets.contains(market)) {
        revert NotControlledMarket();
      }
      assembly {
        let success := call(gas(), market, 0, add(data, 0x20), mload(data), 0, 0)
        if iszero(success) {
          returndatacopy(0, 0, returndatasize())
          revert(0, returndatasize())
        }
      }
    }
  }

  /**
   * @dev Revoke authorization for a set of lenders.
   *
   *      Note: Only updates the internal set of approved lenders.
   *      Must call `updateLenderAuthorization` to apply changes
   *      to existing market accounts
   */
  function deauthorizeLenders(
    address[] memory lenders
  ) external override onlyBorrower sphereXGuardExternal {
    for (uint256 i = 0; i < lenders.length; i++) {
      address lender = lenders[i];
      if (_authorizedLenders.remove(lender)) {
        emit LenderDeauthorized(lender);
      }
    }
  }

  /**
   * @dev Update lender authorization for a set of markets to the current
   *      status.
   */
  function updateLenderAuthorization(
    address lender,
    address[] memory markets
  ) external override sphereXGuardExternal {
    for (uint256 i; i < markets.length; i++) {
      address market = markets[i];
      if (!_controlledMarkets.contains(market)) {
        revert NotControlledMarket();
      }
      address[] memory lenders = new address[](1);
      lenders[0] = lender;
      WildcatMarket(market).updateAccountAuthorizations(
        lenders,
        _authorizedLenders.contains(lender)
      );
    }
  }

  // ========================================================================== //
  //                               Market Queries                               //
  // ========================================================================== //

  function isControlledMarket(address market) external view override returns (bool) {
    return _controlledMarkets.contains(market);
  }

  function getControlledMarkets() external view override returns (address[] memory) {
    return _controlledMarkets.values();
  }

  function getControlledMarkets(
    uint256 start,
    uint256 end
  ) external view override returns (address[] memory arr) {
    uint256 len = _controlledMarkets.length();
    end = MathUtils.min(end, len);
    uint256 count = end - start;
    arr = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      arr[i] = _controlledMarkets.at(start + i);
    }
  }

  function getControlledMarketsCount() external view override returns (uint256) {
    return _controlledMarkets.length();
  }

  function computeMarketAddress(
    address asset,
    string memory namePrefix,
    string memory symbolPrefix
  ) external view override returns (address) {
    bytes32 salt = _deriveSalt(asset, namePrefix, symbolPrefix);
    return LibStoredInitCode.calculateCreate2Address(ownCreate2Prefix, salt, marketInitCodeHash);
  }

  // ========================================================================== //
  //                              Market Deployment                             //
  // ========================================================================== //

  /**
   * @dev Get the temporarily stored market parameters for a market that is
   *      currently being deployed.
   */
  function getMarketParameters()
    external
    view
    override
    returns (MarketParameters memory parameters)
  {
    parameters.asset = _tmpMarketParameters.asset;
    parameters.name = _tmpMarketParameters.name;
    parameters.symbol = _tmpMarketParameters.symbol;
    parameters.borrower = borrower;
    parameters.controller = address(this);
    parameters.feeRecipient = _tmpMarketParameters.feeRecipient;
    parameters.sentinel = sentinel;
    parameters.maxTotalSupply = _tmpMarketParameters.maxTotalSupply;
    parameters.protocolFeeBips = _tmpMarketParameters.protocolFeeBips;
    parameters.annualInterestBips = _tmpMarketParameters.annualInterestBips;
    parameters.delinquencyFeeBips = _tmpMarketParameters.delinquencyFeeBips;
    parameters.withdrawalBatchDuration = _tmpMarketParameters.withdrawalBatchDuration;
    parameters.reserveRatioBips = _tmpMarketParameters.reserveRatioBips;
    parameters.delinquencyGracePeriod = _tmpMarketParameters.delinquencyGracePeriod;
    parameters.archController = _archController;
    parameters.sphereXEngine = sphereXEngine();
  }

  function _resetTmpMarketParameters() internal {
    _tmpMarketParameters.asset = address(1);
    _tmpMarketParameters.name = '_';
    _tmpMarketParameters.symbol = '_';
    _tmpMarketParameters.feeRecipient = address(1);
    _tmpMarketParameters.protocolFeeBips = 1;
    _tmpMarketParameters.maxTotalSupply = 1;
    _tmpMarketParameters.annualInterestBips = 1;
    _tmpMarketParameters.delinquencyFeeBips = 1;
    _tmpMarketParameters.withdrawalBatchDuration = 1;
    _tmpMarketParameters.reserveRatioBips = 1;
    _tmpMarketParameters.delinquencyGracePeriod = 1;
  }

  /**
   * @dev Deploys a create2 deployment of `WildcatMarket` unique to the
   *      combination of `asset, namePrefix, symbolPrefix` and registers
   *      it with the arch-controller.
   *
   *      If a market has already been deployed with these parameters,
   *      reverts with `MarketAlreadyDeployed`.
   *
   *      If `msg.sender` is not `borrower` or `controllerFactory`,
   *      reverts with `CallerNotBorrowerOrControllerFactory`.
   *
   *	    If `msg.sender == borrower && !archController.isRegisteredBorrower(msg.sender)`,
   *		  reverts with `NotRegisteredBorrower`.
   *
   *      If called by `controllerFactory`, skips borrower check.
   *
   *      If either string is empty, reverts with `EmptyString`.
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
  ) external override sphereXGuardExternal returns (address market) {
    if (msg.sender == borrower) {
      if (!IWildcatArchController(_archController).isRegisteredBorrower(msg.sender)) {
        revert NotRegisteredBorrower();
      }
    } else if (msg.sender != address(controllerFactory)) {
      revert CallerNotBorrowerOrControllerFactory();
    }

    enforceParameterConstraints(
      namePrefix,
      symbolPrefix,
      annualInterestBips,
      delinquencyFeeBips,
      withdrawalBatchDuration,
      reserveRatioBips,
      delinquencyGracePeriod
    );

    TmpMarketParameterStorage memory parameters = TmpMarketParameterStorage({
      asset: asset,
      name: string.concat(namePrefix, queryName(asset)),
      symbol: string.concat(symbolPrefix, querySymbol(asset)),
      feeRecipient: address(0),
      maxTotalSupply: maxTotalSupply,
      protocolFeeBips: 0,
      annualInterestBips: annualInterestBips,
      delinquencyFeeBips: delinquencyFeeBips,
      withdrawalBatchDuration: withdrawalBatchDuration,
      reserveRatioBips: reserveRatioBips,
      delinquencyGracePeriod: delinquencyGracePeriod
    });

    address originationFeeAsset;
    uint80 originationFeeAmount;
    (
      parameters.feeRecipient,
      originationFeeAsset,
      originationFeeAmount,
      parameters.protocolFeeBips
    ) = IWildcatMarketControllerFactory(controllerFactory).getProtocolFeeConfiguration();

    _tmpMarketParameters = parameters;

    if (originationFeeAsset != address(0)) {
      originationFeeAsset.safeTransferFrom(borrower, parameters.feeRecipient, originationFeeAmount);
    }

    bytes32 salt = _deriveSalt(asset, namePrefix, symbolPrefix);
    market = LibStoredInitCode.calculateCreate2Address(ownCreate2Prefix, salt, marketInitCodeHash);
    if (market.code.length != 0) {
      revert MarketAlreadyDeployed();
    }
    LibStoredInitCode.create2WithStoredInitCode(marketInitCodeStorage, salt);

    IWildcatArchController(_archController).registerMarket(market);
    _controlledMarkets.add(market);

    _resetTmpMarketParameters();

    emit MarketDeployed(
      market,
      parameters.name,
      parameters.symbol,
      parameters.asset,
      parameters.maxTotalSupply,
      parameters.annualInterestBips,
      parameters.delinquencyFeeBips,
      parameters.withdrawalBatchDuration,
      parameters.reserveRatioBips,
      parameters.delinquencyGracePeriod
    );
  }

  /**
   * @dev Derive create2 salt for a market given the asset address,
   *      name prefix and symbol prefix.
   *
   *      The salt is unique to each market deployment in the controller,
   *      so only one market can be deployed for each combination of `asset`,
   *      `namePrefix` and `symbolPrefix`
   */
  function _deriveSalt(
    address asset,
    string memory namePrefix,
    string memory symbolPrefix
  ) internal pure returns (bytes32 salt) {
    assembly {
      // Cache free memory pointer
      let freeMemoryPointer := mload(0x40)
      // `keccak256(abi.encode(asset, keccak256(namePrefix), keccak256(symbolPrefix)))`
      mstore(0x00, asset)
      mstore(0x20, keccak256(add(namePrefix, 32), mload(namePrefix)))
      mstore(0x40, keccak256(add(symbolPrefix, 32), mload(symbolPrefix)))
      salt := keccak256(0, 0x60)
      // Restore free memory pointer
      mstore(0x40, freeMemoryPointer)
    }
  }

  /**
   * @dev Enforce constraints on market parameters, ensuring that
   *      `annualInterestBips`, `delinquencyFeeBips`, `withdrawalBatchDuration`,
   *      `reserveRatioBips` and `delinquencyGracePeriod` are within the
   *      allowed ranges and that `namePrefix` and `symbolPrefix` are not null.
   */
  function enforceParameterConstraints(
    string memory namePrefix,
    string memory symbolPrefix,
    uint16 annualInterestBips,
    uint16 delinquencyFeeBips,
    uint32 withdrawalBatchDuration,
    uint16 reserveRatioBips,
    uint32 delinquencyGracePeriod
  ) internal view virtual {
    assembly {
      if or(iszero(mload(namePrefix)), iszero(mload(symbolPrefix))) {
        // revert EmptyString();
        mstore(0x00, 0xecd7b0d1)
        revert(0x1c, 0x04)
      }
    }
    assertValueInRange(
      annualInterestBips,
      MinimumAnnualInterestBips,
      MaximumAnnualInterestBips,
      AnnualInterestBipsOutOfBounds.selector
    );
    assertValueInRange(
      delinquencyFeeBips,
      MinimumDelinquencyFeeBips,
      MaximumDelinquencyFeeBips,
      DelinquencyFeeBipsOutOfBounds.selector
    );
    assertValueInRange(
      withdrawalBatchDuration,
      MinimumWithdrawalBatchDuration,
      MaximumWithdrawalBatchDuration,
      WithdrawalBatchDurationOutOfBounds.selector
    );
    assertValueInRange(
      reserveRatioBips,
      MinimumReserveRatioBips,
      MaximumReserveRatioBips,
      ReserveRatioBipsOutOfBounds.selector
    );
    assertValueInRange(
      delinquencyGracePeriod,
      MinimumDelinquencyGracePeriod,
      MaximumDelinquencyGracePeriod,
      DelinquencyGracePeriodOutOfBounds.selector
    );
  }

  // ========================================================================== //
  //                              Market Management                             //
  // ========================================================================== //

  /**
   * @dev Close a market, setting interest rate to zero and returning all
   * outstanding debt.
   */
  function closeMarket(
    address market
  ) external override onlyBorrower onlyControlledMarket(market) sphereXGuardExternal {
    if (WildcatMarket(market).isClosed()) {
      revertWithSelector(MarketAlreadyClosed.selector);
    }

    WildcatMarket(market).closeMarket();
  }

  /**
   * @dev Sets the maximum total supply (capacity) of a market - this only limits
   *      deposits and does not affect interest accrual.
   *
   *      Can not be set lower than the market's current total supply.
   */
  function setMaxTotalSupply(
    address market,
    uint256 maxTotalSupply
  ) external override onlyBorrower onlyControlledMarket(market) sphereXGuardExternal {
    if (WildcatMarket(market).isClosed()) {
      revertWithSelector(CapacityChangeOnClosedMarket.selector);
    }
    WildcatMarket(market).setMaxTotalSupply(maxTotalSupply);
  }

  /**
   * @dev Returns the new temporary reserve ratio for a given interest rate
   *      change. This is calculated as double the relative difference between
   *      the old and new APR rates (in bips), bounded to a maximum of 100%.
   *      If this value is lower than the existing reserve ratio, the existing
   *      reserve ratio is returned instead.
   */
  function _calculateTemporaryReserveRatioBips(
    uint256 annualInterestBips,
    uint256 originalAnnualInterestBips,
    uint256 originalReserveRatioBips
  ) internal pure returns (uint16 temporaryReserveRatioBips) {
    // Calculate double the relative reduction in the interest rate in bips,
    // bound to a maximum of 100%
    uint256 doubleRelativeDiff = MathUtils.mulDiv(
      20000,
      originalAnnualInterestBips - annualInterestBips,
      originalAnnualInterestBips
    );
    uint256 boundRelativeDiff = MathUtils.min(10000, doubleRelativeDiff);
    // If the bound relative diff is lower than the existing reserve ratio, return that instead.
    temporaryReserveRatioBips = uint16(MathUtils.max(boundRelativeDiff, originalReserveRatioBips));
  }

  /**
   * @dev Modify the interest rate for a market.
   *
   *      The original interest rate and reserve ratio are set to those
   *      stored for the market if there is already a temporary reserve
   *      ratio; otherwise, they are the current market values.
   *
   *      If the new interest rate is lower than the original, the reserve
   *      ratio is set to the maximum of the original reserve ratio and
   *      double the relative reduction in the interest rate (in bips),
   *      not exceeding 100%.
   *
   *      If the new interest rate is higher than the original and there
   *      is an existing temporary reserve ratio, it is canceled.
   */
  function setAnnualInterestBips(
    address market,
    uint16 annualInterestBips
  ) external virtual override onlyBorrower onlyControlledMarket(market) sphereXGuardExternal {
    if (WildcatMarket(market).isClosed()) {
      revertWithSelector(AprChangeOnClosedMarket.selector);
    }

    assertValueInRange(
      annualInterestBips,
      MinimumAnnualInterestBips,
      MaximumAnnualInterestBips,
      AnnualInterestBipsOutOfBounds.selector
    );

    // Get the existing temporary reserve ratio from storage, if any
    TemporaryReserveRatio memory tmp = temporaryExcessReserveRatio[market];

    // If there is no temporary reserve ratio, use the current reserve ratio and interest
    // rate from the market for the following calculations; otherwise, use the original
    // values recorded.
    (uint16 originalAnnualInterestBips, uint16 originalReserveRatioBips) = tmp.expiry == 0
      ? (
        uint16(WildcatMarket(market).annualInterestBips()),
        uint16(WildcatMarket(market).reserveRatioBips())
      )
      : (tmp.originalAnnualInterestBips, tmp.originalReserveRatioBips);

    if (annualInterestBips < originalAnnualInterestBips) {
      // If the new interest rate is lower than the original, calculate a temporarily
      // increased reserve ratio as max(originalReserveRatio, min(2 * relativeReduction, 100%))
      uint16 temporaryReserveRatioBips = _calculateTemporaryReserveRatioBips(
        annualInterestBips,
        originalAnnualInterestBips,
        originalReserveRatioBips
      );
      uint32 expiry = uint32(block.timestamp + 2 weeks);
      if (tmp.expiry == 0) {
        // If there is no existing temporary reserve ratio, store the current
        // interest rate and reserve ratio as the original values.
        emit TemporaryExcessReserveRatioActivated(
          market,
          originalReserveRatioBips,
          temporaryReserveRatioBips,
          expiry
        );
        tmp.originalAnnualInterestBips = originalAnnualInterestBips;
        tmp.originalReserveRatioBips = originalReserveRatioBips;
      } else {
        // If the new interest rate is lower than the original but higher than the current
        // interest rate, update the reserve ratio but leave the previous expiry.
        if (annualInterestBips >= WildcatMarket(market).annualInterestBips()) {
          expiry = tmp.expiry;
        }
        emit TemporaryExcessReserveRatioUpdated(
          market,
          originalReserveRatioBips,
          temporaryReserveRatioBips,
          expiry
        );
      }
      tmp.expiry = expiry;
      temporaryExcessReserveRatio[market] = tmp;
      WildcatMarket(market).setReserveRatioBips(temporaryReserveRatioBips);
    } else if (tmp.expiry != 0) {
      // If there is a temporary reserve ratio and the new interest rate is greater
      // than or equal to the original, reset the reserve ratio early.
      emit TemporaryExcessReserveRatioCanceled(market);
      delete temporaryExcessReserveRatio[market];
      WildcatMarket(market).setReserveRatioBips(originalReserveRatioBips);
    }

    WildcatMarket(market).setAnnualInterestBips(annualInterestBips);
  }

  function resetReserveRatio(address market) external virtual override sphereXGuardExternal {
    TemporaryReserveRatio memory tmp = temporaryExcessReserveRatio[market];
    if (tmp.expiry == 0) {
      revertWithSelector(AprChangeNotPending.selector);
    }
    if (block.timestamp < tmp.expiry) {
      revertWithSelector(ExcessReserveRatioStillActive.selector);
    }

    emit TemporaryExcessReserveRatioExpired(market);
    WildcatMarket(market).setReserveRatioBips(uint256(tmp.originalReserveRatioBips).toUint16());
    delete temporaryExcessReserveRatio[market];
  }

  function assertValueInRange(
    uint256 value,
    uint256 min,
    uint256 max,
    bytes4 errorSelector
  ) internal pure {
    assembly {
      if or(lt(value, min), gt(value, max)) {
        mstore(0, errorSelector)
        revert(0, 4)
      }
    }
  }
}
