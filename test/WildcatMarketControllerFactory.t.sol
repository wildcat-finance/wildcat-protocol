// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import 'forge-std/Test.sol';
import 'src/WildcatArchController.sol';
import 'src/WildcatMarketControllerFactory.sol';
import { MinimumDelinquencyGracePeriod, MaximumDelinquencyGracePeriod, MinimumReserveRatioBips, MaximumReserveRatioBips, MinimumDelinquencyFeeBips, MaximumDelinquencyFeeBips, MinimumWithdrawalBatchDuration, MaximumWithdrawalBatchDuration, MinimumAnnualInterestBips, MaximumAnnualInterestBips } from './shared/TestConstants.sol';

contract WildcatMarketControllerFactoryTest is Test {
  WildcatArchController internal archController;
  WildcatMarketControllerFactory internal controllerFactory;
  MarketParameterConstraints internal constraints;

  function setUp() external {
    archController = new WildcatArchController();
    _resetConstraints();
    controllerFactory = new WildcatMarketControllerFactory(
      address(archController),
      address(0),
      constraints
    );
    archController.registerControllerFactory(address(controllerFactory));
    assertEq(controllerFactory.archController(), address(archController), 'archController');
    assertEq(controllerFactory.sentinel(), address(0), 'sentinel');
  }

  function _resetConstraints() internal {
    constraints = MarketParameterConstraints({
      minimumDelinquencyGracePeriod: MinimumDelinquencyGracePeriod,
      maximumDelinquencyGracePeriod: MaximumDelinquencyGracePeriod,
      minimumReserveRatioBips: MinimumReserveRatioBips,
      maximumReserveRatioBips: MaximumReserveRatioBips,
      minimumDelinquencyFeeBips: MinimumDelinquencyFeeBips,
      maximumDelinquencyFeeBips: MaximumDelinquencyFeeBips,
      minimumWithdrawalBatchDuration: MinimumWithdrawalBatchDuration,
      maximumWithdrawalBatchDuration: MaximumWithdrawalBatchDuration,
      minimumAnnualInterestBips: MinimumAnnualInterestBips,
      maximumAnnualInterestBips: MaximumAnnualInterestBips
    });
  }

  function _expectRevertInvalidConstraints() internal {
    vm.expectRevert(IWildcatMarketControllerFactory.InvalidConstraints.selector);
    new WildcatMarketControllerFactory(address(archController), address(0), constraints);
    _resetConstraints();
  }

  function test_InvalidConstraints() external {
    constraints.minimumAnnualInterestBips = constraints.maximumAnnualInterestBips + 1;
    _expectRevertInvalidConstraints();
    constraints.minimumDelinquencyFeeBips = constraints.maximumDelinquencyFeeBips + 1;
    _expectRevertInvalidConstraints();
    constraints.minimumReserveRatioBips = constraints.maximumReserveRatioBips + 1;
    _expectRevertInvalidConstraints();
    constraints.minimumDelinquencyGracePeriod = constraints.maximumDelinquencyGracePeriod + 1;
    _expectRevertInvalidConstraints();
    constraints.minimumWithdrawalBatchDuration = constraints.maximumWithdrawalBatchDuration + 1;
    _expectRevertInvalidConstraints();

    constraints.maximumAnnualInterestBips = 10001;
    _expectRevertInvalidConstraints();
    constraints.maximumDelinquencyFeeBips = 10001;
    _expectRevertInvalidConstraints();
    constraints.maximumReserveRatioBips = 10001;
    _expectRevertInvalidConstraints();
  }

  function test_getParameterConstraints() external {
    MarketParameterConstraints memory constraints = controllerFactory.getParameterConstraints();
    assertEq(
      constraints.minimumDelinquencyGracePeriod,
      MinimumDelinquencyGracePeriod,
      'minimumDelinquencyGracePeriod'
    );
    assertEq(
      constraints.maximumDelinquencyGracePeriod,
      MaximumDelinquencyGracePeriod,
      'maximumDelinquencyGracePeriod'
    );
    assertEq(
      constraints.minimumReserveRatioBips,
      MinimumReserveRatioBips,
      'minimumReserveRatioBips'
    );
    assertEq(
      constraints.maximumReserveRatioBips,
      MaximumReserveRatioBips,
      'maximumReserveRatioBips'
    );
    assertEq(
      constraints.minimumDelinquencyFeeBips,
      MinimumDelinquencyFeeBips,
      'minimumDelinquencyFeeBips'
    );
    assertEq(
      constraints.maximumDelinquencyFeeBips,
      MaximumDelinquencyFeeBips,
      'maximumDelinquencyFeeBips'
    );
    assertEq(
      constraints.minimumWithdrawalBatchDuration,
      MinimumWithdrawalBatchDuration,
      'minimumWithdrawalBatchDuration'
    );
    assertEq(
      constraints.maximumWithdrawalBatchDuration,
      MaximumWithdrawalBatchDuration,
      'maximumWithdrawalBatchDuration'
    );
    assertEq(
      constraints.minimumAnnualInterestBips,
      MinimumAnnualInterestBips,
      'minimumAnnualInterestBips'
    );
    assertEq(
      constraints.maximumAnnualInterestBips,
      MaximumAnnualInterestBips,
      'maximumAnnualInterestBips'
    );
  }

  function test_getMarketControllerParameters() external {
    MarketControllerParameters memory parameters = controllerFactory
      .getMarketControllerParameters();
    assertEq(parameters.archController, address(archController));
    assertEq(parameters.borrower, address(1), 'borrower');
    assertEq(parameters.sentinel, address(0), 'sentinel');
    assertEq(
      parameters.marketInitCodeStorage,
      controllerFactory.marketInitCodeStorage(),
      'marketInitCodeStorage'
    );
    assertEq(
      parameters.marketInitCodeHash,
      controllerFactory.marketInitCodeHash(),
      'marketInitCodeHash'
    );
    assertEq(parameters.marketInitCodeHash, uint256(keccak256(type(WildcatMarket).creationCode)));
    assertEq(
      controllerFactory.controllerInitCodeHash(),
      uint256(keccak256(type(WildcatMarketController).creationCode)),
      'controllerInitCodeHash'
    );

    assertEq(
      parameters.minimumDelinquencyGracePeriod,
      MinimumDelinquencyGracePeriod,
      'minimumDelinquencyGracePeriod'
    );
    assertEq(
      parameters.maximumDelinquencyGracePeriod,
      MaximumDelinquencyGracePeriod,
      'maximumDelinquencyGracePeriod'
    );
    assertEq(
      parameters.minimumReserveRatioBips,
      MinimumReserveRatioBips,
      'minimumReserveRatioBips'
    );
    assertEq(
      parameters.maximumReserveRatioBips,
      MaximumReserveRatioBips,
      'maximumReserveRatioBips'
    );
    assertEq(
      parameters.minimumDelinquencyFeeBips,
      MinimumDelinquencyFeeBips,
      'minimumDelinquencyFeeBips'
    );
    assertEq(
      parameters.maximumDelinquencyFeeBips,
      MaximumDelinquencyFeeBips,
      'maximumDelinquencyFeeBips'
    );
    assertEq(
      parameters.minimumWithdrawalBatchDuration,
      MinimumWithdrawalBatchDuration,
      'minimumWithdrawalBatchDuration'
    );
    assertEq(
      parameters.maximumWithdrawalBatchDuration,
      MaximumWithdrawalBatchDuration,
      'maximumWithdrawalBatchDuration'
    );
    assertEq(
      parameters.minimumAnnualInterestBips,
      MinimumAnnualInterestBips,
      'minimumAnnualInterestBips'
    );
    assertEq(
      parameters.maximumAnnualInterestBips,
      MaximumAnnualInterestBips,
      'maximumAnnualInterestBips'
    );
  }

  function test_setProtocolFeeConfiguration_InvalidProtocolFeeConfiguration() external {
    address notNullFeeRecipient = address(1);
    address nullAddress = address(0);

    vm.expectRevert(IWildcatMarketControllerFactory.InvalidProtocolFeeConfiguration.selector);
    controllerFactory.setProtocolFeeConfiguration(nullAddress, nullAddress, 0, 1);

    vm.expectRevert(IWildcatMarketControllerFactory.InvalidProtocolFeeConfiguration.selector);
    controllerFactory.setProtocolFeeConfiguration(nullAddress, nullAddress, 1, 0);

    vm.expectRevert(IWildcatMarketControllerFactory.InvalidProtocolFeeConfiguration.selector);
    controllerFactory.setProtocolFeeConfiguration(nullAddress, notNullFeeRecipient, 1, 0);

    vm.expectRevert(IWildcatMarketControllerFactory.InvalidProtocolFeeConfiguration.selector);
    controllerFactory.setProtocolFeeConfiguration(nullAddress, nullAddress, 0, 10001);
  }

  function test_deployController_NotRegisteredBorrower() external {
    vm.expectRevert(IWildcatMarketControllerFactory.NotRegisteredBorrower.selector);
    controllerFactory.deployController();
  }

  function test_deployController_ControllerAlreadyDeployed() external {
    archController.registerBorrower(address(1));
    vm.startPrank(address(1));
    controllerFactory.deployController();
    vm.expectRevert(IWildcatMarketControllerFactory.ControllerAlreadyDeployed.selector);
    controllerFactory.deployController();
  }
}
