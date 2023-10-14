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
    vm.expectRevert(WildcatMarketControllerFactory.InvalidConstraints.selector);
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

  function test_getMarketControllerParameters() external {
    MarketControllerParameters memory parameters = controllerFactory.getMarketControllerParameters();
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
}
