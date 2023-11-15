// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { EnumerableSet } from 'openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import './interfaces/WildcatStructsAndEnums.sol';
import './interfaces/IWildcatArchController.sol';
import './interfaces/IWildcatMarketControllerFactory.sol';
import './libraries/LibStoredInitCode.sol';
import './libraries/MathUtils.sol';
import './market/WildcatMarket.sol';
import './WildcatMarketController.sol'; 
import {SphereXProtected} from "@spherex-xyz/contracts/src/SphereXProtected.sol";
 

contract WildcatMarketControllerFactory is IWildcatMarketControllerFactory , SphereXProtected {
  using EnumerableSet for EnumerableSet.AddressSet;

  // Returns immutable arch-controller
  address public immutable override archController;

  // Returns sentinel used by controller
  address public immutable override sentinel;

  address public immutable override marketInitCodeStorage;

  uint256 public immutable override marketInitCodeHash;

  address public immutable override controllerInitCodeStorage;

  uint256 public immutable override controllerInitCodeHash;

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

  ProtocolFeeConfiguration internal _protocolFeeConfiguration;

  EnumerableSet.AddressSet internal _deployedControllers;

  modifier onlyArchControllerOwner() {
    if (msg.sender != IWildcatArchController(archController).owner()) {
      revert CallerNotArchControllerOwner();
    }
    _;
  }

  constructor(
    address _archController,
    address _sentinel,
    MarketParameterConstraints memory constraints
  ) {
    archController = _archController;
    sentinel = _sentinel;
    if (
      constraints.minimumAnnualInterestBips > constraints.maximumAnnualInterestBips ||
      constraints.maximumAnnualInterestBips > 10000 ||
      constraints.minimumDelinquencyFeeBips > constraints.maximumDelinquencyFeeBips ||
      constraints.maximumDelinquencyFeeBips > 10000 ||
      constraints.minimumReserveRatioBips > constraints.maximumReserveRatioBips ||
      constraints.maximumReserveRatioBips > 10000 ||
      constraints.minimumDelinquencyGracePeriod > constraints.maximumDelinquencyGracePeriod ||
      constraints.minimumWithdrawalBatchDuration > constraints.maximumWithdrawalBatchDuration
    ) {
      revert InvalidConstraints();
    }
    MinimumDelinquencyGracePeriod = constraints.minimumDelinquencyGracePeriod;
    MaximumDelinquencyGracePeriod = constraints.maximumDelinquencyGracePeriod;
    MinimumReserveRatioBips = constraints.minimumReserveRatioBips;
    MaximumReserveRatioBips = constraints.maximumReserveRatioBips;
    MinimumDelinquencyFeeBips = constraints.minimumDelinquencyFeeBips;
    MaximumDelinquencyFeeBips = constraints.maximumDelinquencyFeeBips;
    MinimumWithdrawalBatchDuration = constraints.minimumWithdrawalBatchDuration;
    MaximumWithdrawalBatchDuration = constraints.maximumWithdrawalBatchDuration;
    MinimumAnnualInterestBips = constraints.minimumAnnualInterestBips;
    MaximumAnnualInterestBips = constraints.maximumAnnualInterestBips;

    (controllerInitCodeStorage, controllerInitCodeHash) = _storeControllerInitCode();
    (marketInitCodeStorage, marketInitCodeHash) = _storeMarketInitCode();
  }

  function _storeControllerInitCode()
    internal
    virtual
    sphereXGuardInternal(0x0eee275d) returns (address initCodeStorage, uint256 initCodeHash)
  {
    bytes memory controllerInitCode = type(WildcatMarketController).creationCode;
    initCodeHash = uint256(keccak256(controllerInitCode));
    initCodeStorage = LibStoredInitCode.deployInitCode(controllerInitCode);
  }

  function _storeMarketInitCode()
    internal
    virtual
    sphereXGuardInternal(0x3351b929) returns (address initCodeStorage, uint256 initCodeHash)
  {
    bytes memory marketInitCode = type(WildcatMarket).creationCode;
    initCodeHash = uint256(keccak256(marketInitCode));
    initCodeStorage = LibStoredInitCode.deployInitCode(marketInitCode);
  }

  function isDeployedController(address controller) external view override returns (bool) {
    return _deployedControllers.contains(controller);
  }

  function getDeployedControllersCount() external view override returns (uint256) {
    return _deployedControllers.length();
  }

  function getDeployedControllers() external view override returns (address[] memory) {
    return _deployedControllers.values();
  }

  function getDeployedControllers(
    uint256 start,
    uint256 end
  ) external view override returns (address[] memory arr) {
    uint256 len = _deployedControllers.length();
    end = MathUtils.min(end, len);
    uint256 count = end - start;
    arr = new address[](count);
    for (uint256 i = 0; i < count; i++) {
      arr[i] = _deployedControllers.at(start + i);
    }
  }

  /**
   * @dev Returns protocol fee configuration for new markets.
   *
   *      These can be updated by the arch-controller owner but
   *      `protocolFeeBips` and `feeRecipient` are immutable once
   *      a market is deployed.
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
    return (
      _protocolFeeConfiguration.feeRecipient,
      _protocolFeeConfiguration.originationFeeAsset,
      _protocolFeeConfiguration.originationFeeAmount,
      _protocolFeeConfiguration.protocolFeeBips
    );
  }

  /**
   * @dev Sets protocol fee configuration for new market deployments via
   *      controllers deployed by this factory.
   *
   *      If caller is not `archController.owner()`, reverts with
   *      `NotArchControllerOwner`.
   *
   *      Revert with `InvalidProtocolFeeConfiguration` if:
   *      - `protocolFeeBips > 0 && feeRecipient == address(0)`
   *      - OR `originationFeeAmount > 0 && originationFeeAsset == address(0)`
   *      - OR `originationFeeAmount > 0 && feeRecipient == address(0)`
   */
  function setProtocolFeeConfiguration(
    address feeRecipient,
    address originationFeeAsset,
    uint80 originationFeeAmount,
    uint16 protocolFeeBips
  ) external override onlyArchControllerOwner sphereXGuardExternal(0x490e86f1) {
    bool hasOriginationFee = originationFeeAmount > 0;
    bool nullFeeRecipient = feeRecipient == address(0);
    bool nullOriginationFeeAsset = originationFeeAsset == address(0);
    if (
      (protocolFeeBips > 0 && nullFeeRecipient) ||
      (hasOriginationFee && nullFeeRecipient) ||
      (hasOriginationFee && nullOriginationFeeAsset)
    ) {
      revert InvalidProtocolFeeConfiguration();
    }
    _protocolFeeConfiguration = ProtocolFeeConfiguration({
      feeRecipient: feeRecipient,
      originationFeeAsset: originationFeeAsset,
      originationFeeAmount: originationFeeAmount,
      protocolFeeBips: protocolFeeBips
    });
    emit UpdateProtocolFeeConfiguration(
      feeRecipient,
      protocolFeeBips,
      originationFeeAsset,
      originationFeeAmount
    );
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

  /* -------------------------------------------------------------------------- */
  /*                            Controller Deployment                           */
  /* -------------------------------------------------------------------------- */

  address internal _tmpMarketBorrowerParameter = address(1);

  function getMarketControllerParameters()
    external
    view
    virtual
    override
    returns (MarketControllerParameters memory parameters)
  {
    parameters.archController = address(archController);
    parameters.borrower = _tmpMarketBorrowerParameter;
    parameters.sentinel = sentinel;
    parameters.marketInitCodeStorage = marketInitCodeStorage;
    parameters.marketInitCodeHash = marketInitCodeHash;
    parameters.minimumDelinquencyGracePeriod = MinimumDelinquencyGracePeriod;
    parameters.maximumDelinquencyGracePeriod = MaximumDelinquencyGracePeriod;
    parameters.minimumReserveRatioBips = MinimumReserveRatioBips;
    parameters.maximumReserveRatioBips = MaximumReserveRatioBips;
    parameters.minimumDelinquencyFeeBips = MinimumDelinquencyFeeBips;
    parameters.maximumDelinquencyFeeBips = MaximumDelinquencyFeeBips;
    parameters.minimumWithdrawalBatchDuration = MinimumWithdrawalBatchDuration;
    parameters.maximumWithdrawalBatchDuration = MaximumWithdrawalBatchDuration;
    parameters.minimumAnnualInterestBips = MinimumAnnualInterestBips;
    parameters.maximumAnnualInterestBips = MaximumAnnualInterestBips;
    parameters.spherex_admin = sphereXAdmin();
    parameters.spherex_operator = sphereXOperator();
    parameters.spherex_engine = sphereXEngine();
  }

  /**
   * @dev Deploys a create2 deployment of `WildcatMarketController`
   *      unique to the borrower and registers it with the arch-controller.
   *
   *      If a controller is already deployed for the borrower, reverts
   *      with `ControllerAlreadyDeployed`.
   *
   *	  If `archController.isRegisteredBorrower(msg.sender)` returns false
   *      reverts with `NotRegisteredBorrower`.
   *
   *      Calls `archController.registerController(controller)` and emits
   *      `NewController(borrower, controller)`.
   */
  function deployController() public override sphereXGuardPublic(0x45223233, 0x7cc9788e) returns (address controller) {
    if (!IWildcatArchController(archController).isRegisteredBorrower(msg.sender)) {
      revert NotRegisteredBorrower();
    }
    _tmpMarketBorrowerParameter = msg.sender;
    // Salt is borrower address
    bytes32 salt = bytes32(uint256(uint160(msg.sender)));
    controller = LibStoredInitCode.calculateCreate2Address(
      ownCreate2Prefix,
      salt,
      controllerInitCodeHash
    );

    if (controller.code.length != 0) {
      revert ControllerAlreadyDeployed();
    }
    LibStoredInitCode.create2WithStoredInitCode(controllerInitCodeStorage, salt);
    _tmpMarketBorrowerParameter = address(1);
    IWildcatArchController(archController).registerController(controller);
    _deployedControllers.add(controller);

    _addAllowedSenderOnChain(controller);
    emit NewController(msg.sender, controller);
  }

  /**
   * @dev Deploys a create2 deployment of `WildcatMarketController`
   *      unique to the borrower and registers it with the arch-controller,
   *      then deploys a new market through the controller.
   *
   *      If a controller is already deployed for the borrower, reverts
   *      with `ControllerAlreadyDeployed`.
   *
   *	  If `archController.isRegisteredBorrower(msg.sender)` returns false
   *	  reverts with `NotRegisteredBorrower`.
   *
   *      Calls `archController.registerController(controller)` and emits
   * 	  `NewController(borrower, controller, namePrefix, symbolPrefix)`.
   */
  function deployControllerAndMarket(
    string memory namePrefix,
    string memory symbolPrefix,
    address asset,
    uint128 maxTotalSupply,
    uint16 annualInterestBips,
    uint16 delinquencyFeeBips,
    uint32 withdrawalBatchDuration,
    uint16 reserveRatioBips,
    uint32 delinquencyGracePeriod
  ) external override sphereXGuardExternal(0x5e82b681) returns (address controller, address market) {
    controller = deployController();
    market = IWildcatMarketController(controller).deployMarket(
      asset,
      namePrefix,
      symbolPrefix,
      maxTotalSupply,
      annualInterestBips,
      delinquencyFeeBips,
      withdrawalBatchDuration,
      reserveRatioBips,
      delinquencyGracePeriod
    );
    _addAllowedSenderOnChain(market);
  }

  function computeControllerAddress(address borrower) external view override returns (address) {
    // Salt is borrower address
    bytes32 salt = bytes32(uint256(uint160(borrower)));
    return
      LibStoredInitCode.calculateCreate2Address(ownCreate2Prefix, salt, controllerInitCodeHash);
  }
}