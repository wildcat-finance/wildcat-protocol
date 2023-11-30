// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20;

import './ArchControllerData.sol';
import './MarketData.sol';
import './ControllerData.sol';
import './TokenData.sol';

contract MarketLens {
  WildcatArchController public immutable archController;
  WildcatMarketControllerFactory public immutable controllerFactory;

  constructor(address _archController) {
    archController = WildcatArchController(_archController);
    address[] memory factories = archController.getRegisteredControllerFactories();
    require(factories.length == 1, 'should only have one factory');
    controllerFactory = WildcatMarketControllerFactory(factories[0]);
  }

  /* -------------------------------------------------------------------------- */
  /*                           Arch-controller queries                          */
  /* -------------------------------------------------------------------------- */

  modifier checkSlice(SliceParameters memory slice) {
    if (slice.end == 0 && slice.start == 0) {
      slice.end = type(uint256).max;
    }
    _;
  }

  function getArchControllerData() external view returns (ArchControllerData memory data) {
    SliceParameters memory sliceAll = SliceParameters({ start: 0, end: type(uint256).max });
    data.fill(archController, sliceAll, sliceAll, sliceAll, sliceAll);
  }

  function getPaginatedArchControllerData(
    SliceParameters memory borrowersSlice,
    SliceParameters memory controllerFactoriesSlice,
    SliceParameters memory controllersSlice,
    SliceParameters memory marketsSlice
  )
    public
    view
    checkSlice(borrowersSlice)
    checkSlice(controllerFactoriesSlice)
    checkSlice(controllersSlice)
    checkSlice(marketsSlice)
    returns (ArchControllerData memory data)
  {
    data.fill(
      archController,
      SliceParameters(0, 0),
      SliceParameters(0, 0),
      SliceParameters(0, 0),
      SliceParameters(0, 0)
    );
  }

  /* -------------------------------------------------------------------------- */
  /*                             Controller queries                             */
  /* -------------------------------------------------------------------------- */

  function getControllerDataForBorrower(
    address borrower
  ) public view returns (ControllerData memory data) {
    data.fill(archController, controllerFactory, borrower);
  }

  function getControllersDataForBorrowers(
    address[] memory borrowers
  ) public view returns (ControllerData[] memory data) {
    data = new ControllerData[](borrowers.length);
    for (uint256 i; i < borrowers.length; i++) {
      data[i].fill(archController, controllerFactory, borrowers[i]);
    }
  }

  function getPaginatedControllersDataForBorrowers(
    uint256 start,
    uint256 end
  ) public view returns (ControllerData[] memory data) {
    address[] memory borrowers = archController.getRegisteredBorrowers(start, end);
    return getControllersDataForBorrowers(borrowers);
  }

  function getAllControllersDataForBorrowers()
    external
    view
    returns (ControllerData[] memory data)
  {
    address[] memory borrowers = archController.getRegisteredBorrowers();
    return getControllersDataForBorrowers(borrowers);
  }

  /* -------------------------------------------------------------------------- */
  /*                                Token queries                               */
  /* -------------------------------------------------------------------------- */

  function getTokenInfo(address token) public view returns (TokenMetadata memory info) {
    info.fill(token);
  }

  function getTokensInfo(
    address[] memory tokens
  ) public view returns (TokenMetadata[] memory info) {
    info = new TokenMetadata[](tokens.length);
    for (uint256 i; i < tokens.length; i++) {
      info[i].fill(tokens[i]);
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                               Market queries                               */
  /* -------------------------------------------------------------------------- */

  function getMarketsCount() external view returns (uint256) {
    return archController.getRegisteredMarketsCount();
  }

  function getMarketData(address market) public view returns (MarketData memory data) {
    data.fill(WildcatMarket(market));
  }

  function getMarketsData(address[] memory markets) public view returns (MarketData[] memory data) {
    data = new MarketData[](markets.length);
    for (uint256 i; i < markets.length; i++) {
      data[i].fill(WildcatMarket(markets[i]));
    }
  }

  function getPaginatedMarketsData(
    uint256 start,
    uint256 end
  ) public view returns (MarketData[] memory data) {
    address[] memory markets = archController.getRegisteredMarkets(start, end);
    return getMarketsData(markets);
  }

  function getAllMarketsData() external view returns (MarketData[] memory data) {
    address[] memory markets = archController.getRegisteredMarkets();
    return getMarketsData(markets);
  }

  /* -------------------------------------------------------------------------- */
  /*                          Market and account queries                         */
  /* -------------------------------------------------------------------------- */

  function getMarketDataWithLenderStatus(
    address lender,
    address market
  ) public view returns (MarketDataWithLenderStatus memory data) {
    data.fill(WildcatMarket(market), lender);
  }

  function getMarketsDataWithLenderStatus(
    address lender,
    address[] memory markets
  ) public view returns (MarketDataWithLenderStatus[] memory data) {
    data = new MarketDataWithLenderStatus[](markets.length);
    for (uint256 i; i < markets.length; i++) {
      data[i].fill(WildcatMarket(markets[i]), lender);
    }
  }

  function getPaginatedMarketsDataWithLenderStatus(
    address lender,
    uint256 start,
    uint256 end
  ) public view returns (MarketDataWithLenderStatus[] memory data) {
    address[] memory markets = archController.getRegisteredMarkets(start, end);
    return getMarketsDataWithLenderStatus(lender, markets);
  }

  function getAllMarketsDataWithLenderStatus(
    address lender
  ) external view returns (MarketDataWithLenderStatus[] memory data) {
    address[] memory markets = archController.getRegisteredMarkets();
    return getMarketsDataWithLenderStatus(lender, markets);
  }

  /* -------------------------------------------------------------------------- */
  /*                               Lender queries                               */
  /* -------------------------------------------------------------------------- */

  function getMarketLenderStatus(
    address lender,
    address market
  ) external view returns (MarketLenderStatus memory status) {
    status.fill(WildcatMarket(market), lender);
  }

  function getMarketsLenderStatus(
    address lender,
    address[] memory market
  ) external view returns (MarketLenderStatus[] memory status) {
    status = new MarketLenderStatus[](market.length);
    for (uint256 i; i < market.length; i++) {
      status[i].fill(WildcatMarket(market[i]), lender);
    }
  }

  function getAllMarketsLenderStatus(
    address lender
  ) external view returns (MarketLenderStatus[] memory status) {
    address[] memory markets = archController.getRegisteredMarkets();
    status = new MarketLenderStatus[](markets.length);
    for (uint256 i; i < markets.length; i++) {
      status[i].fill(WildcatMarket(markets[i]), lender);
    }
  }

  function queryLenderAccount(
    LenderAccountQuery memory query
  ) external view returns (LenderAccountQueryResult memory result) {
    result.fill(query);
  }

  function queryLenderAccounts(
    LenderAccountQuery[] memory queries
  ) external view returns (LenderAccountQueryResult[] memory result) {
    result = new LenderAccountQueryResult[](queries.length);
    for (uint256 i; i < queries.length; i++) {
      result[i].fill(queries[i]);
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                          Withdrawal batch queries                          */
  /* -------------------------------------------------------------------------- */

  function getWithdrawalBatchData(
    address market,
    uint32 expiry
  ) public view returns (WithdrawalBatchData memory data) {
    data.fill(WildcatMarket(market), expiry);
  }

  function getWithdrawalBatchesData(
    address market,
    uint32[] memory expiries
  ) public view returns (WithdrawalBatchData[] memory data) {
    data = new WithdrawalBatchData[](expiries.length);
    for (uint256 i; i < expiries.length; i++) {
      data[i].fill(WildcatMarket(market), expiries[i]);
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                    Withdrawal batch queries with account                   */
  /* -------------------------------------------------------------------------- */

  function getWithdrawalBatchesDataWithLenderStatus(
    address market,
    uint32[] memory expiries,
    address lender
  ) external view returns (WithdrawalBatchDataWithLenderStatus[] memory statuses) {
    statuses = new WithdrawalBatchDataWithLenderStatus[](expiries.length);
    for (uint256 i; i < expiries.length; i++) {
      statuses[i].fill(WildcatMarket(market), expiries[i], lender);
    }
  }

  function getWithdrawalBatchDataWithLenderStatus(
    address market,
    uint32 expiry,
    address lender
  ) external view returns (WithdrawalBatchDataWithLenderStatus memory status) {
    status.fill(WildcatMarket(market), expiry, lender);
  }

  function getWithdrawalBatchDataWithLendersStatus(
    address market,
    uint32 expiry,
    address[] calldata lenders
  )
    external
    view
    returns (WithdrawalBatchData memory batch, WithdrawalBatchLenderStatus[] memory statuses)
  {
    batch.fill(WildcatMarket(market), expiry);

    statuses = new WithdrawalBatchLenderStatus[](lenders.length);
    for (uint256 i; i < lenders.length; i++) {
      statuses[i].fill(WildcatMarket(market), batch, lenders[i]);
    }
  }
}
