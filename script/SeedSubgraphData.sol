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

string constant DeploymentsJsonFilePath = 'deployments.json';

contract SeedSubgraphData is Script {
  using LibDeployment for JsonObject;
  using SafeTransferLib for address;

  modifier asLender() {
    ctx.startBroadcast(env.getUint('LENDER_PVT_KEY'));
    _;
    ctx.stopBroadcast();
  }

  function deposit(WildcatMarket market, MockERC20 erc20, uint256 amount) internal {
    address lender = env.getAddress('LENDER');
    ctx.startBroadcast(env.getUint('LENDER_PVT_KEY'));
    erc20.mint(lender, amount);
    erc20.approve(address(market), amount);
    market.deposit(amount);
    ctx.stopBroadcast();
  }

  function borrow(WildcatMarket market, uint256 amount) internal {
    address borrower = env.getAddress('BORROWER');
    ctx.startBroadcast(env.getUint('BORROWER_PVT_KEY'));
    market.borrow(amount);
    ctx.stopBroadcast();
  }

  function withdraw(WildcatMarket market, uint256 amount) internal {
    address lender = env.getAddress('LENDER');
    ctx.startBroadcast(env.getUint('LENDER_PVT_KEY'));
    market.queueWithdrawal(amount);
    ctx.stopBroadcast();
  }

  function deployControllerAndMarket(
    JsonObject memory deployments
  ) internal returns (WildcatMarketController controller, WildcatMarket market, MockERC20 erc20) {
    address borrower = env.getAddress('BORROWER');
    address lender = env.getAddress('LENDER');
    MockERC20Factory erc20Factory = MockERC20Factory(deployments.get('MockERC20Factory'));
    MockArchControllerOwner archControllerOwner = MockArchControllerOwner(
      deployments.get('MockArchControllerOwner')
    );
    WildcatMarketControllerFactory controllerFactory = WildcatMarketControllerFactory(
      deployments.get('WildcatMarketControllerFactory')
    );
    controller = WildcatMarketController(controllerFactory.computeControllerAddress(borrower));
    address[] memory lenders = new address[](1);
    lenders[0] = lender;

    ctx.startBroadcast(env.getUint('BORROWER_PVT_KEY'));
    archControllerOwner.registerBorrower(borrower);
    erc20 = MockERC20(erc20Factory.deploy('Fake USDC', 'FUSDC'));

    (, address marketAddress) = controllerFactory.deployControllerAndMarket(
      'Wildcat ',
      'wc',
      address(erc20),
      100_000_000e18,
      1500,
      1000,
      uint32(30 minutes),
      2_000,
      uint32(60 minutes)
    );
    market = WildcatMarket(marketAddress);
    controller.authorizeLenders(lenders);
    ctx.stopBroadcast();
  }

  function fund(address account) internal {
    if (account.balance == 0) {
      ctx.startBroadcast(env.getUint('PVT_KEY'));
      account.safeTransferETH(1e17);
      ctx.stopBroadcast();
    }
  }

  function run() public virtual {
    fund(env.getAddress('BORROWER'));
    fund(env.getAddress('LENDER'));
    JsonObject memory deployments = getDeploymentsFile(DeploymentsJsonFilePath);
    (
      WildcatMarketController controller,
      WildcatMarket market,
      MockERC20 erc20
    ) = deployControllerAndMarket(deployments);

    deposit(market, erc20, 1_000e18);
    borrow(market, 799e18);
    withdraw(market, 1_000e18);

    console.log('market: ', address(market));
    console.log('controller: ', address(controller));
  }
}
