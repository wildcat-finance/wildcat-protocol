// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import './BaseMarketTest.sol';
import 'src/libraries/MathUtils.sol';
import 'src/libraries/SafeCastLib.sol';
import 'src/libraries/MarketState.sol';
import 'solady/utils/SafeTransferLib.sol';
import 'src/lens/MarketLens.sol';
import { ERC20 } from 'solmate/tokens/ERC20.sol';

contract MarketLensTest is BaseMarketTest {
  MarketLens internal lens;

  function setUp() public virtual override {
    super.setUp();
    lens = new MarketLens(address(archController));
  }

  function toArray(address addr) internal pure returns (address[] memory arr) {
    arr = new address[](1);
    arr[0] = addr;
  }

  function checkData(MarketData memory data) internal {
    assertEq(address(market), data.marketToken.token, 'underlying token');
    assertEq(market.name(), data.marketToken.name, 'underlying name');
    assertEq(market.symbol(), data.marketToken.symbol, 'underlying symbol');
    assertEq(market.decimals(), data.marketToken.decimals, 'underlying decimals');

    assertEq(address(asset), data.underlyingToken.token, 'underlying token');
    assertEq(asset.name(), data.underlyingToken.name, 'underlying name');
    assertEq(asset.symbol(), data.underlyingToken.symbol, 'underlying symbol');
    assertEq(asset.decimals(), data.underlyingToken.decimals, 'underlying decimals');

    assertEq(market.borrower(), data.borrower, 'borrower');
    assertEq(market.controller(), data.controller, 'controller');
    assertEq(market.feeRecipient(), data.feeRecipient, 'feeRecipient');

    assertEq(market.annualInterestBips(), data.annualInterestBips, 'annualInterestBips');

    assertEq(market.protocolFeeBips(), data.protocolFeeBips, 'protocolFeeBips');
    assertEq(market.delinquencyFeeBips(), data.delinquencyFeeBips, 'delinquencyFeeBips');
    assertEq(
      market.withdrawalBatchDuration(),
      data.withdrawalBatchDuration,
      'withdrawalBatchDuration'
    );
    assertEq(
      market.delinquencyGracePeriod(),
      data.delinquencyGracePeriod,
      'delinquencyGracePeriod'
    );
    assertEq(market.reserveRatioBips(), data.reserveRatioBips, 'reserveRatioBips');

    (, uint128 tmpReserveRatioBips, uint128 temporaryReserveRatioExpiry) = controller
      .temporaryExcessReserveRatio(address(market));
    assertEq(data.temporaryReserveRatio, temporaryReserveRatioExpiry != 0, 'temporaryReserveRatio');
    assertEq(data.originalReserveRatioBips, tmpReserveRatioBips, 'originalReserveRatioBips');
    assertEq(
      data.temporaryReserveRatioExpiry,
      temporaryReserveRatioExpiry,
      'temporaryReserveRatioExpiry'
    );

    assertEq(market.borrowableAssets(), data.borrowableAssets, 'borrowableAssets');
    assertEq(market.maxTotalSupply(), data.maxTotalSupply, 'maxTotalSupply');
    assertEq(market.totalSupply(), data.totalSupply, 'totalSupply');
    assertEq(market.totalAssets(), data.totalAssets, 'totalAssets');
    assertEq(market.coverageLiquidity(), data.coverageLiquidity, 'coverageLiquidity');
    assertEq(market.accruedProtocolFees(), data.lastAccruedProtocolFees, 'lastAccruedProtocolFees');

    MarketState memory state = market.currentState();

    assertEq(data.isClosed, state.isClosed, 'isClosed');
    assertEq(state.scaleFactor, data.scaleFactor, 'scaleFactor');

    assertEq(
      data.normalizedUnclaimedWithdrawals,
      state.normalizedUnclaimedWithdrawals,
      'normalizedUnclaimedWithdrawals'
    );
    assertEq(
      data.scaledPendingWithdrawals,
      state.scaledPendingWithdrawals,
      'scaledPendingWithdrawals'
    );
    assertEq(
      data.pendingWithdrawalExpiry,
      state.pendingWithdrawalExpiry,
      'pendingWithdrawalExpiry'
    );

    assertEq(state.scaledTotalSupply, data.scaledTotalSupply, 'scaledTotalSupply');
    assertEq(state.isDelinquent, data.isDelinquent, 'isDelinquent');
    assertEq(state.timeDelinquent, data.timeDelinquent, 'timeDelinquent');
    assertEq(
      state.lastInterestAccruedTimestamp,
      data.lastInterestAccruedTimestamp,
      'lastInterestAccruedTimestamp'
    );
  }

  function test_getMarketData() external {
    checkData(lens.getMarketData(address(market)));

    vm.prank(alice);
    market.depositUpTo(1e18);

    vm.prank(borrower);
    controller.setAnnualInterestBips(address(market), DefaultInterest * 2);

    checkData(lens.getMarketData(address(market)));

    vm.prank(borrower);
    market.borrow(8e17);

    checkData(lens.getMarketData(address(market)));

    vm.prank(alice);
    market.queueWithdrawal(1e18);

    checkData(lens.getMarketData(address(market)));
  }

  function test_getMarketsData() external {
    address[] memory markets = new address[](1);
    markets[0] = address(market);
    MarketData[] memory arr = lens.getMarketsData(markets);

    checkData(arr[0]);
  }

  function test_getPaginatedMarketsData() external {
    MarketData[] memory arr = lens.getPaginatedMarketsData(0, 1);
    checkData(arr[0]);
  }

  function test_getAllMarketsData() external {
    MarketData[] memory arr = lens.getAllMarketsData();
    checkData(arr[0]);
    assertEq(arr.length, 1);
  }

  function checkMarketDataWithLenderStatus(
    address account,
    MarketDataWithLenderStatus memory data
  ) internal {
    checkData(data.market);

    assertEq(data.lenderStatus.scaledBalance, market.scaledBalanceOf(account), 'scaledBalance');
    assertEq(data.lenderStatus.normalizedBalance, market.balanceOf(account), 'normalizedBalance');
    assertEq(data.lenderStatus.underlyingBalance, asset.balanceOf(account), 'underlyingBalance');
    assertEq(
      data.lenderStatus.underlyingApproval,
      asset.allowance(account, address(market)),
      'underlyingApproval'
    );
    assertEq(data.lenderStatus.lender, account, 'lender');
    assertEq(
      data.lenderStatus.isAuthorizedOnController,
      controller.isAuthorizedLender(account),
      'isAuthorizedOnController'
    );
    assertEq(uint256(data.lenderStatus.role), uint256(market.getAccountRole(account)), 'role');
  }

  function test_getMarketDataWithLenderStatus() external {
    _deposit(alice, 100e18);
    MarketDataWithLenderStatus memory data = lens.getMarketDataWithLenderStatus(
      alice,
      address(market)
    );
    checkMarketDataWithLenderStatus(alice, data);
  }

  function test_getMarketsDataWithLenderStatus() external {
    _deposit(alice, 100e18);
    address[] memory markets = new address[](1);
    markets[0] = address(market);
    MarketDataWithLenderStatus[] memory arr = lens.getMarketsDataWithLenderStatus(alice, markets);
    checkMarketDataWithLenderStatus(alice, arr[0]);
  }

  function test_getPaginatedMarketsDataWithLenderStatus() external {
    _deposit(alice, 100e18);
    MarketDataWithLenderStatus[] memory arr = lens.getPaginatedMarketsDataWithLenderStatus(
      alice,
      0,
      1
    );
    checkMarketDataWithLenderStatus(alice, arr[0]);
  }

  function test_getAllMarketsDataWithLenderStatus() external {
    _deposit(alice, 100e18);
    MarketDataWithLenderStatus[] memory arr = lens.getAllMarketsDataWithLenderStatus(alice);
    checkMarketDataWithLenderStatus(alice, arr[0]);
    assertEq(arr.length, 1);
  }

  function test_getArchControllerData() external {
    ArchControllerData memory metadata = lens.getArchControllerData();
    assertEq(metadata.archController, address(archController), 'archController');
    assertEq(
      metadata.borrowersCount,
      archController.getRegisteredBorrowersCount(),
      'borrowersCount'
    );
    assertEq(metadata.borrowers, toArray(parameters.borrower), 'borrowers');
    assertEq(
      metadata.controllerFactoriesCount,
      archController.getRegisteredControllerFactoriesCount(),
      'controllerFactoriesCount'
    );
    assertEq(
      metadata.controllerFactories,
      toArray(address(controllerFactory)),
      'controllerFactories'
    );
    assertEq(
      metadata.controllersCount,
      archController.getRegisteredControllersCount(),
      'controllersCount'
    );
    assertEq(metadata.controllers, toArray(address(controller)), 'controllers');
    assertEq(metadata.marketsCount, archController.getRegisteredMarketsCount(), 'marketsCount');
    assertEq(metadata.markets, toArray(address(market)), 'markets');
  }

  function test_controllerData(
    address _borrower,
    bool registered,
    bool _deployController,
    bool originationFee,
    uint256 originationFeeAmount,
    uint256 originationFeeBalance,
    uint256 originationFeeApproval
  ) external {
    address _controller;
    vm.assume(_borrower != borrower && _borrower != address(0));
    _deployController = registered && _deployController;
    if (!originationFee) {
      originationFeeAmount = 0;
      originationFeeBalance = 0;
      originationFeeApproval = 0;
    } else {
      originationFeeAmount = bound(originationFeeAmount, 1, type(uint80).max);
    }
    if (registered) {
      if (_deployController) {
        deployController(_borrower, false, false);
        _controller = address(controller);
      } else {
        archController.registerBorrower(_borrower);
        _controller = controllerFactory.computeControllerAddress(_borrower);
      }
    } else {
      _controller = controllerFactory.computeControllerAddress(_borrower);
    }

    TokenMetadata memory originationFeeAsset;

    if (originationFee) {
      MockERC20 originationFeeToken = new MockERC20('feetok', 'fees', 18);
      controllerFactory.setProtocolFeeConfiguration(
        parameters.feeRecipient,
        address(originationFeeToken),
        uint80(originationFeeAmount),
        parameters.protocolFeeBips
      );
      originationFeeAsset = TokenMetadata({
        token: address(originationFeeToken),
        name: 'feetok',
        symbol: 'fees',
        decimals: 18,
        isMock: false
      });
      if (originationFeeBalance > 0) {
        originationFeeToken.mint(_borrower, originationFeeBalance);
      }
      if (originationFeeApproval > 0) {
        vm.prank(_borrower);
        originationFeeToken.approve(_controller, originationFeeApproval);
      }
    } else {
      controllerFactory.setProtocolFeeConfiguration(
        parameters.feeRecipient,
        address(0),
        uint80(0),
        parameters.protocolFeeBips
      );
    }

    ControllerData memory data = lens.getControllerDataForBorrower(_borrower);
    assertEq(data.borrower, _borrower, 'borrower');
    assertEq(data.controller, _controller, 'controller');
    assertEq(data.controllerFactory, address(controllerFactory), 'controllerFactory');
    assertEq(data.isRegisteredBorrower, registered, 'isRegisteredBorrower');
    assertEq(data.hasDeployedController, _deployController, 'hasDeployedController');
    assertEq(
      data.borrowerOriginationFeeBalance,
      originationFeeBalance,
      'borrowerOriginationFeeBalance'
    );
    assertEq(
      data.borrowerOriginationFeeApproval,
      originationFeeApproval,
      'borrowerOriginationFeeApproval'
    );
    assertEq(
      keccak256(abi.encode(data.constraints)),
      keccak256(abi.encode(controller.getParameterConstraints())),
      'constraints'
    );

    assertEq(data.fees.feeRecipient, parameters.feeRecipient, 'feeRecipient');
    assertEq(data.fees.protocolFeeBips, parameters.protocolFeeBips, 'protocolFeeBips');
    assertEq(data.fees.originationFeeToken.token, originationFeeAsset.token, 'originationFeeToken');
    assertEq(data.fees.originationFeeToken.name, originationFeeAsset.name, 'originationFeeToken');
    assertEq(
      data.fees.originationFeeToken.symbol,
      originationFeeAsset.symbol,
      'originationFeeToken'
    );
    assertEq(
      data.fees.originationFeeToken.decimals,
      originationFeeAsset.decimals,
      'originationFeeToken'
    );
    assertEq(data.fees.originationFeeAmount, originationFeeAmount, 'originationFeeAmount');

    assertEq(data.markets.length, 0, 'markets.length');
  }

  function checkWithdrawalBatchData(WithdrawalBatchData memory data, uint32 expiry) internal {
    WithdrawalBatch memory batch = market.getWithdrawalBatch(expiry);
    assertEq(data.expiry, expiry, 'expiry');

    assertEq(
      uint256(data.status),
      uint256(
        expiry > block.timestamp
          ? BatchStatus.Pending
          : batch.scaledTotalAmount == batch.scaledAmountBurned
          ? BatchStatus.Complete
          : BatchStatus.Unpaid
      ),
      'status'
    );
    assertEq(data.scaledTotalAmount, batch.scaledTotalAmount, 'scaledTotalAmount');
    assertEq(data.scaledAmountBurned, batch.scaledAmountBurned, 'scaledAmountBurned');
    assertEq(data.normalizedAmountPaid, batch.normalizedAmountPaid, 'normalizedAmountPaid');
    uint256 remainder = MathUtils.rayMul(
      batch.scaledTotalAmount - batch.scaledAmountBurned,
      market.scaleFactor()
    );

    assertEq(
      data.normalizedTotalAmount,
      data.normalizedAmountPaid + remainder,
      'normalizedTotalAmount'
    );
  }

  function test_getWithdrawalBatchData() external {
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    uint32 expiry = uint32(block.timestamp + parameters.withdrawalBatchDuration);
    checkWithdrawalBatchData(lens.getWithdrawalBatchData(address(market), expiry), expiry);
    fastForward(parameters.withdrawalBatchDuration + 1);
    market.updateState();
    checkWithdrawalBatchData(lens.getWithdrawalBatchData(address(market), expiry), expiry);
    asset.mint(address(market), 1e18);
    market.repayAndProcessUnpaidWithdrawalBatches(0, 1);
    checkWithdrawalBatchData(lens.getWithdrawalBatchData(address(market), expiry), expiry);
  }

  function checkWithdrawalBatchLenderStatus(
    WithdrawalBatchLenderStatus memory data,
    uint32 expiry,
    address lender
  ) internal {
    assertEq(data.lender, lender, 'lender');
    AccountWithdrawalStatus memory status = market.getAccountWithdrawalStatus(lender, expiry);
    assertEq(data.scaledAmount, status.scaledAmount, 'scaledAmount');
    assertEq(
      data.normalizedAmountWithdrawn,
      status.normalizedAmountWithdrawn,
      'normalizedAmountWithdrawn'
    );
    WithdrawalBatch memory batch = market.getWithdrawalBatch(expiry);
    uint256 scaledAmountOwed = batch.scaledTotalAmount - batch.scaledAmountBurned;

    uint256 normalizedAmountOwed = MathUtils.rayMul(scaledAmountOwed, market.scaleFactor());
    uint256 normalizedTotalAmount = batch.normalizedAmountPaid + normalizedAmountOwed;
    assertEq(
      data.normalizedAmountOwed,
      MathUtils.mulDiv(normalizedTotalAmount, data.scaledAmount, batch.scaledTotalAmount) -
        status.normalizedAmountWithdrawn,
      'normalizedAmountOwed'
    );
    assertEq(
      data.availableWithdrawalAmount,
      expiry > block.timestamp
        ? MathUtils.mulDiv(batch.normalizedAmountPaid, data.scaledAmount, batch.scaledTotalAmount)
        : market.getAvailableWithdrawalAmount(lender, expiry),
      'availableWithdrawalAmount'
    );
  }

  function checkWithdrawalBatchDataWithLenderStatus(
    WithdrawalBatchDataWithLenderStatus memory data,
    uint32 expiry
  ) internal {
    checkWithdrawalBatchData(data.batch, expiry);
    checkWithdrawalBatchLenderStatus(data.lenderStatus, expiry, data.lenderStatus.lender);
  }

  function test_getLenderWithdrawalStatus() external {
    _depositBorrowWithdraw(alice, 1e18, 8e17, 1e18);
    uint32 expiry = uint32(block.timestamp + parameters.withdrawalBatchDuration);
    checkWithdrawalBatchDataWithLenderStatus(
      lens.getWithdrawalBatchDataWithLenderStatus(address(market), uint32(expiry), address(alice)),
      expiry
    );
    fastForward(parameters.withdrawalBatchDuration + 1);

    vm.prank(alice);
    market.executeWithdrawal(alice, expiry);
    checkWithdrawalBatchDataWithLenderStatus(
      lens.getWithdrawalBatchDataWithLenderStatus(address(market), uint32(expiry), address(alice)),
      expiry
    );

    asset.mint(address(market), 1e18);
    market.repayAndProcessUnpaidWithdrawalBatches(0, 1);
    checkWithdrawalBatchDataWithLenderStatus(
      lens.getWithdrawalBatchDataWithLenderStatus(address(market), uint32(expiry), address(alice)),
      expiry
    );

    vm.prank(alice);
    market.executeWithdrawal(alice, expiry);
    checkWithdrawalBatchDataWithLenderStatus(
      lens.getWithdrawalBatchDataWithLenderStatus(address(market), uint32(expiry), address(alice)),
      expiry
    );
  }

  // function test_getControllerData() external {
  //   MockERC20 originationFeeToken = new ERC20('feetok', 'fees', 18);
  //   controllerFactory.setProtocolFeeConfiguration(
  //     parameters.feeRecipient,
  //     address(originationFeeToken),
  //     1e18,
  //     parameters.protocolFeeBips
  //   );

  //   ControllerData memory data = lens.getControllerData(address(controller));
  //   assertEq(data.borrower, parameters.borrower, 'borrower');
  //   assertEq(data.controller, address(controller), 'controller');
  //   assertEq(data.controllerFactory, address(controllerFactory), 'controllerFactory');
  //   assertEq(data.isRegisteredBorrower, true, 'isRegisteredBorrower');
  //   assertEq(data.hasDeployedController, true, 'hasDeployedController');
  //   assertEq(data.borrowerOriginationFeeBalance, 0, 'borrowerOriginationFeeBalance');
  //   assertEq(
  //     keccak256(abi.encode(data.constraints)),
  //     keccak256(abi.encode(controller.getParameterConstraints())),
  //     'constraints'
  //   );

  //   assertEq(
  //     keccak256(abi.encode(data.fees)),
  //     keccak256(
  //       abi.encode(
  //         FeeConfiguration({
  //           feeRecipient: parameters.feeRecipient,
  //           protocolFeeBips: parameters.protocolFeeBips,
  //           originationFeeToken: TokenMetadata({
  //             token: address(originationFeeToken),
  //             name: 'feetok',
  //             symbol: 'fees',
  //             decimals: 18
  //           }),
  //           originationFeeAmount: 1e18
  //         })
  //       )
  //     ),
  //     'fees'
  //   );
  // }

  /*   function test_getMarketControllerFactoryData() external {
    controllerFactory.setProtocolFeeConfiguration(
      parameters.feeRecipient,
      address(asset),
      1e18,
      parameters.protocolFeeBips
    );
    MarketControllerFactoryData memory data = lens.getMarketControllerFactoryData(
      address(controllerFactory)
    );
    assertEq(data.feeRecipient, parameters.feeRecipient, 'feeRecipient');
    assertEq(data.protocolFeeBips, parameters.protocolFeeBips, 'protocolFeeBips');
    assertEq(data.controllersCount, 1, 'controllersCount');
    assertEq(data.originationFeeAsset, address(asset), 'originationFeeAsset');
    assertEq(data.originationFeeAmount, 1e18, 'originationFeeAmount');
    assertEq(keccak256(abi.encode(data.constraints)), keccak256(abi.encode(controllerFactory.getParameterConstraints())), 'constraints');
    } */
}
