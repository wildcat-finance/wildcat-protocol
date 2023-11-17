// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import 'vulcan/script.sol';

function getDeploymentsFile(string memory deploymentsJsonFilePath) returns (JsonObject memory) {
  if (fs.fileExists(deploymentsJsonFilePath).unwrap()) {
    return json.create(fs.readFile(deploymentsJsonFilePath).unwrap()).unwrap();
  }
  return json.create();
}

library LibDeployment {
  using LibDeployment for JsonObject;

  function get(JsonObject memory obj, string memory name) internal pure returns (address) {
    return obj.getAddress(string.concat('.', name));
  }

  function has(JsonObject memory obj, string memory name) internal returns (bool) {
    return obj.containsKey(string.concat('.', name));
  }

  function getOrDeploy(
    JsonObject memory deployments,
    string memory name,
    bytes memory initCode,
    bool overrideExisting
  ) internal returns (address deployment, bool didDeploy) {
    if (overrideExisting || !deployments.has(name)) {
      ctx.startBroadcast(env.getUint('PVT_KEY'));
      assembly {
        deployment := create(0, add(initCode, 0x20), mload(initCode))
      }
      ctx.stopBroadcast();
      deployments.set(name, deployment);
      didDeploy = true;
    } else {
      deployment = deployments.get(name);
    }
    console.log(string.concat(didDeploy ? 'Deployed ' : 'Found ', name, ' at'), deployment);
  }

  function getOrDeploy(
    JsonObject memory deployments,
    string memory name,
    bytes memory initCode
  ) internal returns (address deployment, bool didDeploy) {
    return getOrDeploy(deployments, name, initCode, false);
  }

  function deploy(
    JsonObject memory deployments,
    string memory name,
    bytes memory initCode
  ) internal returns (address deployment) {
    (deployment, ) = getOrDeploy(deployments, name, initCode, true);
  }
}
