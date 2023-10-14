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

contract Test is ForgeTest, Prankster {
  WildcatArchController internal archController;
  WildcatMarketControllerFactory internal controllerFactory;
  WildcatMarketController internal controller;
  WildcatMarket internal market;
  MockSanctionsSentinel internal sanctionsSentinel;

  modifier asSelf() {
    startPrank(address(this));
    _;
    stopPrank();
  }

  constructor() {
    deployMockChainalysis();
    archController = new WildcatArchController();
    sanctionsSentinel = new MockSanctionsSentinel(address(archController));
    controllerFactory = new MockControllerFactory(
      address(archController),
      address(sanctionsSentinel)
    );
    archController.registerControllerFactory(address(controllerFactory));
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
  }

  function deployController(
    address borrower,
    bool authorizeAll,
    bool disableConstraints
  ) internal asSelf {
    archController.registerBorrower(borrower);
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
    stopPrank();
    if (disableConstraints) {
      _controller.toggleParameterChecks();
    }
    if (authorizeAll) {
      _controller.authorizeAll();
    }
    controller = _controller;
  }

  function updateFeeConfiguration(MarketParameters memory parameters) internal asSelf {
    controllerFactory.setProtocolFeeConfiguration(
      parameters.feeRecipient,
      address(0),
      0,
      parameters.protocolFeeBips
    );
  }

  function deployMarket(MarketParameters memory parameters) internal asAccount(parameters.borrower) {
    updateFeeConfiguration(parameters);
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
  }

  function deployControllerAndMarket(
    MarketParameters memory parameters,
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
