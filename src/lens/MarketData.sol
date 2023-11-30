// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import '../market/WildcatMarket.sol';
import '../WildcatMarketController.sol';
import '../WildcatArchController.sol';
import '../WildcatMarketControllerFactory.sol';
import './TokenData.sol';

using MarketDataLib for MarketData global;
using MarketDataLib for MarketLenderStatus global;
using MarketDataLib for MarketDataWithLenderStatus global;
using MarketDataLib for WithdrawalBatchData global;
using MarketDataLib for WithdrawalBatchLenderStatus global;
using MarketDataLib for WithdrawalBatchDataWithLenderStatus global;
using MarketDataLib for LenderAccountQueryResult global;

struct MarketData {
  // -- Tokens metadata --
  TokenMetadata marketToken;
  TokenMetadata underlyingToken;
  // -- Market configuration --
  address borrower;
  address controller;
  address feeRecipient;
  uint256 protocolFeeBips;
  uint256 delinquencyFeeBips;
  uint256 delinquencyGracePeriod;
  uint256 withdrawalBatchDuration;
  uint256 reserveRatioBips;
  uint256 annualInterestBips;
  bool temporaryReserveRatio; // reserveRatioBips increased by APR reduction
  uint256 originalAnnualInterestBips;
  uint256 originalReserveRatioBips;
  uint256 temporaryReserveRatioExpiry;
  // -- Market state --
  bool isClosed;
  uint256 scaleFactor;
  uint256 totalSupply;
  uint256 maxTotalSupply;
  uint256 scaledTotalSupply;
  uint256 totalAssets;
  uint256 lastAccruedProtocolFees;
  uint256 normalizedUnclaimedWithdrawals;
  uint256 scaledPendingWithdrawals;
  uint256 pendingWithdrawalExpiry;
  bool isDelinquent;
  uint256 timeDelinquent;
  uint256 lastInterestAccruedTimestamp;
  uint32[] unpaidWithdrawalBatchExpiries;
  uint256 coverageLiquidity;
  uint256 borrowableAssets;
  uint256 delinquentDebt;
}

struct MarketQuery {
  address market;
  bool includeImmutables;
}

struct MarketLenderStatus {
  address lender;
  bool isAuthorizedOnController;
  AuthRole role;
  uint256 scaledBalance;
  uint256 normalizedBalance;
  uint256 underlyingBalance;
  uint256 underlyingApproval;
}

struct MarketDataWithLenderStatus {
  MarketData market;
  MarketLenderStatus lenderStatus;
}

enum BatchStatus {
  Pending,
  Expired,
  Unpaid,
  Complete
}

struct WithdrawalBatchData {
  uint32 expiry;
  BatchStatus status;
  uint256 scaledTotalAmount;
  uint256 scaledAmountBurned;
  uint256 normalizedAmountPaid;
  uint256 normalizedTotalAmount;
}

struct WithdrawalBatchLenderStatus {
  address lender;
  uint256 scaledAmount;
  uint256 normalizedAmountWithdrawn;
  uint256 normalizedAmountOwed;
  uint256 availableWithdrawalAmount;
}

struct WithdrawalBatchDataWithLenderStatus {
  WithdrawalBatchData batch;
  WithdrawalBatchLenderStatus lenderStatus;
}

struct LenderAccountQuery {
  address lender;
  address market;
  uint32[] withdrawalBatchExpiries;
}

struct LenderAccountQueryResult {
  MarketData market;
  MarketLenderStatus lenderStatus;
  WithdrawalBatchDataWithLenderStatus[] withdrawalBatches;
}

library MarketDataLib {
  using MathUtils for uint256;

  function fill(MarketData memory data, WildcatMarket market) internal view {
    data.marketToken.fill(address(market));
    data.underlyingToken.fill(market.asset());

    data.borrower = market.borrower();
    data.controller = market.controller();
    data.feeRecipient = market.feeRecipient();
    data.protocolFeeBips = market.protocolFeeBips();
    data.delinquencyFeeBips = market.delinquencyFeeBips();
    data.delinquencyGracePeriod = market.delinquencyGracePeriod();
    data.withdrawalBatchDuration = market.withdrawalBatchDuration();

    (
      data.originalAnnualInterestBips,
      data.originalReserveRatioBips,
      data.temporaryReserveRatioExpiry
    ) = WildcatMarketController(market.controller()).temporaryExcessReserveRatio(address(market));
    data.temporaryReserveRatio = data.temporaryReserveRatioExpiry > 0;

    data.unpaidWithdrawalBatchExpiries = market.getUnpaidBatchExpiries();

    MarketState memory state = market.currentState();
    if (state.pendingWithdrawalExpiry == 0) {
      uint32 expiredBatchExpiry = market.previousState().pendingWithdrawalExpiry;
      if (expiredBatchExpiry > 0) {
        WithdrawalBatch memory expiredBatch = market.getWithdrawalBatch(expiredBatchExpiry);

        if (expiredBatch.scaledTotalAmount == expiredBatch.scaledAmountBurned) {
          data.pendingWithdrawalExpiry = expiredBatchExpiry;
        } else {
          uint32[] memory unpaidWithdrawalBatchExpiries = data.unpaidWithdrawalBatchExpiries;
          data.unpaidWithdrawalBatchExpiries = new uint32[](
            unpaidWithdrawalBatchExpiries.length + 1
          );
          for (uint256 i; i < unpaidWithdrawalBatchExpiries.length; i++) {
            data.unpaidWithdrawalBatchExpiries[i] = unpaidWithdrawalBatchExpiries[i];
          }
          data.unpaidWithdrawalBatchExpiries[
            unpaidWithdrawalBatchExpiries.length
          ] = expiredBatchExpiry;
        }
      }
    }

    data.isClosed = state.isClosed;
    data.totalAssets = market.totalAssets();
    data.lastAccruedProtocolFees = market.accruedProtocolFees();
    data.coverageLiquidity = state.liquidityRequired();

    data.borrowableAssets = data.totalAssets.satSub(data.coverageLiquidity);

    data.annualInterestBips = state.annualInterestBips;
    data.reserveRatioBips = state.reserveRatioBips;
    data.maxTotalSupply = state.maxTotalSupply;
    data.scaledTotalSupply = state.scaledTotalSupply;
    data.totalSupply = state.totalSupply();

    data.scaleFactor = state.scaleFactor;
    data.isDelinquent = state.isDelinquent;
    data.timeDelinquent = state.timeDelinquent;
    data.lastInterestAccruedTimestamp = state.lastInterestAccruedTimestamp;

    data.normalizedUnclaimedWithdrawals = state.normalizedUnclaimedWithdrawals;
    data.scaledPendingWithdrawals = state.scaledPendingWithdrawals;
    data.pendingWithdrawalExpiry = state.pendingWithdrawalExpiry;
  }

  function getUnpaidAndPendingWithdrawalBatches(
    MarketData memory data
  ) internal view returns (WithdrawalBatchData[] memory unpaidAndPendingWithdrawalBatches) {
    WildcatMarket market = WildcatMarket(data.marketToken.token);
    bool hasPendingWithdrawalBatch = data.pendingWithdrawalExpiry > 0;
    uint256 unpaidExpiriesCount = data.unpaidWithdrawalBatchExpiries.length;
    unpaidAndPendingWithdrawalBatches = new WithdrawalBatchData[](
      unpaidExpiriesCount + (hasPendingWithdrawalBatch ? 1 : 0)
    );
    for (uint256 i; i < unpaidExpiriesCount; i++) {
      unpaidAndPendingWithdrawalBatches[i].fill(market, data.unpaidWithdrawalBatchExpiries[i]);
    }
    if (data.pendingWithdrawalExpiry > 0) {
      unpaidAndPendingWithdrawalBatches[unpaidExpiriesCount].fill(
        market,
        uint32(data.pendingWithdrawalExpiry)
      );
    }
  }

  function fill(
    MarketLenderStatus memory status,
    MarketData memory marketData,
    address lender
  ) internal view {
    WildcatMarket market = WildcatMarket(marketData.marketToken.token);
    WildcatMarketController controller = WildcatMarketController(marketData.controller);

    status.lender = lender;
    status.role = market.getAccountRole(lender);
    status.isAuthorizedOnController = controller.isAuthorizedLender(lender);

    status.scaledBalance = market.scaledBalanceOf(lender);
    status.normalizedBalance = market.balanceOf(lender);

    IERC20 underlying = IERC20(marketData.underlyingToken.token);
    status.underlyingBalance = underlying.balanceOf(lender);
    status.underlyingApproval = underlying.allowance(lender, address(market));
  }

  function fill(
    MarketLenderStatus memory status,
    WildcatMarket market,
    address lender
  ) internal view {
    WildcatMarketController controller = WildcatMarketController(market.controller());

    status.lender = lender;
    status.role = market.getAccountRole(lender);
    status.isAuthorizedOnController = controller.isAuthorizedLender(lender);

    status.scaledBalance = market.scaledBalanceOf(lender);
    status.normalizedBalance = market.balanceOf(lender);

    IERC20 underlying = IERC20(market.asset());
    status.underlyingBalance = underlying.balanceOf(lender);
    status.underlyingApproval = underlying.allowance(lender, address(market));
  }

  function fill(
    MarketDataWithLenderStatus memory data,
    WildcatMarket market,
    address lender
  ) internal view {
    data.market.fill(market);
    data.lenderStatus.fill(data.market, lender);
  }

  function fill(
    WithdrawalBatchData memory data,
    WildcatMarket market,
    uint32 expiry
  ) internal view {
    WithdrawalBatch memory batch = market.getWithdrawalBatch(expiry);
    data.expiry = expiry;
    data.scaledTotalAmount = batch.scaledTotalAmount;
    data.scaledAmountBurned = batch.scaledAmountBurned;
    data.normalizedAmountPaid = batch.normalizedAmountPaid;
    if (expiry >= block.timestamp) {
      data.status = BatchStatus.Pending;
    } else if (expiry > market.previousState().lastInterestAccruedTimestamp) {
      data.status = BatchStatus.Expired;
    } else {
      data.status = data.scaledAmountBurned == data.scaledTotalAmount
        ? BatchStatus.Complete
        : BatchStatus.Unpaid;
    }
    if (data.scaledAmountBurned != data.scaledTotalAmount) {
      uint256 scaledAmountOwed = data.scaledTotalAmount - data.scaledAmountBurned;
      uint256 normalizedAmountOwed = MathUtils.rayMul(scaledAmountOwed, market.scaleFactor());
      data.normalizedTotalAmount = data.normalizedAmountPaid + normalizedAmountOwed;
    } else {
      data.normalizedTotalAmount = data.normalizedAmountPaid;
    }
  }

  function fill(
    WithdrawalBatchLenderStatus memory data,
    WildcatMarket market,
    WithdrawalBatchData memory batch,
    address lender
  ) internal view {
    data.lender = lender;
    AccountWithdrawalStatus memory status = market.getAccountWithdrawalStatus(lender, batch.expiry);
    data.scaledAmount = status.scaledAmount;
    data.normalizedAmountWithdrawn = status.normalizedAmountWithdrawn;
    data.normalizedAmountOwed =
      MathUtils.mulDiv(batch.normalizedTotalAmount, data.scaledAmount, batch.scaledTotalAmount) -
      data.normalizedAmountWithdrawn;
    data.availableWithdrawalAmount =
      MathUtils.mulDiv(batch.normalizedAmountPaid, data.scaledAmount, batch.scaledTotalAmount) -
      data.normalizedAmountWithdrawn;
  }

  function fill(
    WithdrawalBatchDataWithLenderStatus memory data,
    WildcatMarket market,
    uint32 expiry,
    address lender
  ) internal view {
    data.batch.fill(market, expiry);
    data.lenderStatus.fill(market, data.batch, lender);
  }

  function fill(
    LenderAccountQueryResult memory result,
    LenderAccountQuery memory query
  ) internal view {
    WildcatMarket market = WildcatMarket(query.market);
    result.market.fill(market);
    result.lenderStatus.fill(result.market, query.lender);

    result.withdrawalBatches = new WithdrawalBatchDataWithLenderStatus[](
      query.withdrawalBatchExpiries.length
    );
    for (uint256 i; i < query.withdrawalBatchExpiries.length; i++) {
      result.withdrawalBatches[i].fill(market, query.withdrawalBatchExpiries[i], query.lender);
    }
  }
}
