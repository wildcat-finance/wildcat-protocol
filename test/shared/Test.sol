// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { console, console2, StdAssertions, StdChains, StdCheats, stdError, StdInvariant, stdJson, stdMath, StdStorage, stdStorage, StdUtils, Vm, StdStyle, DSTest, Test as ForgeTest } from 'forge-std/Test.sol';
import { Prankster } from 'sol-utils/test/Prankster.sol';

import 'src/WildcatArchController.sol';
import { WildcatSanctionsSentinel } from 'src/WildcatSanctionsSentinel.sol';

import '../helpers/VmUtils.sol' as VmUtils;
import '../helpers/MockControllerFactory.sol';
import '../helpers/MockSanctionsSentinel.sol';
import { deployMockChainalysis } from '../helpers/MockChainalysis.sol';

struct MarketInputParameters {
  address asset;
  string namePrefix;
  string symbolPrefix;
  address borrower;
  address controller;
  address feeRecipient;
  address sentinel;
  uint128 maxTotalSupply;
  uint16 protocolFeeBips;
  uint16 annualInterestBips;
  uint16 delinquencyFeeBips;
  uint32 withdrawalBatchDuration;
  uint16 reserveRatioBips;
  uint32 delinquencyGracePeriod;
  address sphereXAdmin;
  address sphereXOperator;
  address sphereXEngine;
}

contract Test is ForgeTest, Prankster, IWildcatMarketControllerEventsAndErrors {
  WildcatArchController internal archController;
  WildcatMarketControllerFactory internal controllerFactory;
  WildcatMarketController internal controller;
  WildcatMarket internal market;
  MockSanctionsSentinel internal sanctionsSentinel;
  address internal SphereXAdmin = address(this);
  address internal SphereXOperator = address(0x08374708);
  address internal SphereXEngine;

  modifier asSelf() {
    startPrank(address(this));
    _;
    stopPrank();
  }

  constructor() {
    deployBaseContracts();
  }

  function deployBaseContracts() internal asSelf {
    deployMockChainalysis();
    archController = new WildcatArchController();
    sanctionsSentinel = new MockSanctionsSentinel(address(archController));
    controllerFactory = new MockControllerFactory(
      address(archController),
      address(sanctionsSentinel)
    );
    archController.registerControllerFactory(address(controllerFactory));
    _checkSphereXConfig(address(controllerFactory), 'WildcatMarketControllerFactory');
  }

  function _checkSphereXConfig(address contractAddress, string memory label) internal asSelf {
    SphereXProtectedRegisteredBase _contract = SphereXProtectedRegisteredBase(contractAddress);
    assertEq(_contract.sphereXOperator(), SphereXOperator, string.concat(label, ': sphereXOperator'));
    assertEq(_contract.sphereXEngine(), SphereXEngine, string.concat(label, ': sphereXEngine'));
  }

  event ControllerAdded(address indexed controllerFactory, address controller);
  event ChangedSpherexOperator(address oldSphereXAdmin, address newSphereXAdmin);
  event ChangedSpherexEngineAddress(address oldEngineAddress, address newEngineAddress);
  event SpherexAdminTransferStarted(address currentAdmin, address pendingAdmin);
  event SpherexAdminTransferCompleted(address oldAdmin, address newAdmin);
  event NewAllowedSenderOnchain(address sender);
  event NewController(address borrower, address controller);

  function deployController(
    address borrower,
    bool authorizeAll,
    bool disableConstraints
  ) internal asSelf {
    archController.registerBorrower(borrower);
    address expectedController = controllerFactory.computeControllerAddress(borrower);
    vm.expectEmit(expectedController);
    emit SpherexAdminTransferCompleted(address(0), SphereXAdmin);
    vm.expectEmit(expectedController);
    emit ChangedSpherexOperator(address(0), SphereXOperator);
    vm.expectEmit(expectedController);
    emit ChangedSpherexEngineAddress(address(0), SphereXEngine);
    vm.expectEmit(address(archController));
    emit ControllerAdded(address(controllerFactory), expectedController);
    vm.expectEmit(address(controllerFactory));
    emit NewController(borrower, expectedController);
    vm.expectEmit(address(controllerFactory));
    emit NewAllowedSenderOnchain(expectedController);
    startPrank(borrower);
    MockController _controller = MockController(controllerFactory.deployController());
    assertTrue(
      controllerFactory.isDeployedController(address(_controller)),
      'controller not recognized by factory'
    );
    assertTrue(
      archController.isRegisteredController(address(_controller)),
      'controller not recognized by arch controller'
    );
    _checkSphereXConfig(address(_controller), 'WildcatMarketController');
    stopPrank();
    if (disableConstraints) {
      _controller.toggleParameterChecks();
    }
    if (authorizeAll) {
      _controller.authorizeAll();
    }
    controller = _controller;
  }

  event UpdateProtocolFeeConfiguration(
    address feeRecipient,
    uint16 protocolFeeBips,
    address originationFeeAsset,
    uint256 originationFeeAmount
  );

  function updateFeeConfiguration(MarketInputParameters memory parameters) internal asSelf {
    vm.expectEmit(address(controllerFactory));
    emit UpdateProtocolFeeConfiguration(
      parameters.feeRecipient,
      parameters.protocolFeeBips,
      address(0),
      0
    );
    controllerFactory.setProtocolFeeConfiguration(
      parameters.feeRecipient,
      address(0),
      0,
      parameters.protocolFeeBips
    );
  }

  function deployMarket(
    MarketInputParameters memory parameters
  ) internal asAccount(parameters.borrower) {
    updateFeeConfiguration(parameters);
    address expectedMarket = controller.computeMarketAddress(
      parameters.asset,
      parameters.namePrefix,
      parameters.symbolPrefix
    );
    string memory expectedName = string.concat(
      parameters.namePrefix,
      IERC20Metadata(parameters.asset).name()
    );
    string memory expectedSymbol = string.concat(
      parameters.symbolPrefix,
      IERC20Metadata(parameters.asset).symbol()
    );
/*     vm.expectEmit(address(controller));
    emit MarketDeployed(
      expectedMarket,
      expectedName,
      expectedSymbol,
      parameters.asset,
      parameters.maxTotalSupply,
      parameters.annualInterestBips,
      parameters.delinquencyFeeBips,
      parameters.withdrawalBatchDuration,
      parameters.reserveRatioBips,
      parameters.delinquencyGracePeriod
    ); */
    vm.expectEmit(address(controller));
    emit NewAllowedSenderOnchain(expectedMarket);
    market = WildcatMarket(
      controller.deployMarket(
        parameters.asset,
        parameters.namePrefix,
        parameters.symbolPrefix,
        parameters.maxTotalSupply,
        parameters.annualInterestBips,
        parameters.delinquencyFeeBips,
        parameters.withdrawalBatchDuration,
        parameters.reserveRatioBips,
        parameters.delinquencyGracePeriod
      )
    );
    assertTrue(
      controller.isControlledMarket(address(market)),
      'deployed market is not recognized by the controller'
    );
    assertTrue(
      archController.isRegisteredMarket(address(market)),
      'deployed market is not recognized by the arch controller'
    );
    _checkSphereXConfig(address(market), 'WildcatMarket');
  }

  function deployControllerAndMarket(
    MarketInputParameters memory parameters,
    bool authorizeAll,
    bool disableConstraints
  ) internal {
    deployController(parameters.borrower, authorizeAll, disableConstraints);

    deployMarket(parameters);
  }

  function bound(
    uint256 value,
    uint256 min,
    uint256 max
  ) internal view virtual override returns (uint256 result) {
    return VmUtils.bound(value, min, max);
  }

  function dbound(
    uint256 value1,
    uint256 value2,
    uint256 min,
    uint256 max
  ) internal view virtual returns (uint256, uint256) {
    return VmUtils.dbound(value1, value2, min, max);
  }
}
