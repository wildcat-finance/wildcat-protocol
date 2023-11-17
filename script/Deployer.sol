// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import 'src/WildcatMarketControllerFactory.sol';
import 'src/WildcatSanctionsSentinel.sol';
import 'src/WildcatArchController.sol';
import './mock/MockERC20Factory.sol';
import './mock/MockArchControllerOwner.sol';
import './mock/MockChainalysis.sol';
import 'src/lens/MarketLens.sol';
import 'vulcan/script.sol';
import './LibDeployment.sol';

using LibDeployment for JsonObject;

string constant DeploymentsJsonFilePath = 'deployments.json';
bool constant RedoAllDeployments = true;

contract Deployer is Script {
  function run() public virtual {
    JsonObject memory deployments = getDeploymentsFile(DeploymentsJsonFilePath);
    /* ------------------------------- chainalysis ------------------------------ */
    (address chainalysis, ) = deployments.getOrDeploy(
      'MockChainalysis',
      type(MockChainalysis).creationCode
    );
    /* ----------------------------- arch controller ---------------------------- */
    (address archController, bool didDeployArchController) = deployments.getOrDeploy(
      'WildcatArchController',
      type(WildcatArchController).creationCode,
      RedoAllDeployments
    );
    /* -------------------------- arch controller owner ------------------------- */
    (address archControllerOwner, bool didDeployArchControllerOwner) = deployments.getOrDeploy(
      'MockArchControllerOwner',
      abi.encodePacked(type(MockArchControllerOwner).creationCode, abi.encode(archController)),
      didDeployArchController
    );
    /* -------------------------------- sentinel -------------------------------- */
    (address sentinel, ) = deployments.getOrDeploy(
      'WildcatSanctionsSentinel',
      abi.encodePacked(
        type(WildcatSanctionsSentinel).creationCode,
        abi.encode(archController, chainalysis)
      ),
      didDeployArchController
    );
    /* --------------------------- controller factory --------------------------- */
    (address controllerFactory, bool didDeployControllerFactory) = deployments.getOrDeploy(
      'WildcatMarketControllerFactory',
      abi.encodePacked(
        type(WildcatMarketControllerFactory).creationCode,
        abi.encode(archController, sentinel, getParameterConstraints())
      ),
      didDeployArchController
    );

    /* ----------------------- register controller factory ---------------------- */
    if (didDeployControllerFactory) {
      ctx.startBroadcast(env.getUint('PVT_KEY'));
      WildcatArchController(archController).registerControllerFactory(controllerFactory);
      ctx.stopBroadcast();
      console.log('Registered controller factory on arch controller');
    }

    /* ------------------ transfer ownership of arch-controller ----------------- */
    if (didDeployArchControllerOwner) {
      ctx.startBroadcast(env.getUint('PVT_KEY'));
      WildcatArchController(archController).transferOwnership(archControllerOwner);
      ctx.stopBroadcast();
    }

    /* ---------------------------------- lens ---------------------------------- */
    deployments.getOrDeploy(
      'MarketLens',
      abi.encodePacked(type(MarketLens).creationCode, abi.encode(archController)),
      didDeployControllerFactory
    );

    /* --------------------------- mock token factory --------------------------- */
    deployments.getOrDeploy(
      'MockERC20Factory',
      type(MockERC20Factory).creationCode,
      RedoAllDeployments
    );

    deployments.write(DeploymentsJsonFilePath);
  }
}

function getParameterConstraints() pure returns (MarketParameterConstraints memory) {
  return
    MarketParameterConstraints({
      minimumDelinquencyGracePeriod: 0,
      maximumDelinquencyGracePeriod: 90 days,
      minimumReserveRatioBips: 0,
      maximumReserveRatioBips: 10_000,
      minimumDelinquencyFeeBips: 0,
      maximumDelinquencyFeeBips: 10_000,
      minimumWithdrawalBatchDuration: 0,
      maximumWithdrawalBatchDuration: 7 days,
      minimumAnnualInterestBips: 0,
      maximumAnnualInterestBips: 10_000
    });
}
