## LOC

```
github.com/AlDanial/cloc v 1.98  T=0.03 s (1336.5 files/s, 169696.7 lines/s)
------------------------------------------------------------------------------------------------------------
File                                                                     blank        comment           code
------------------------------------------------------------------------------------------------------------
src/WildcatMarketController.sol                                              61             92            361
src/market/WildcatMarketBase.sol                                            68            113            311
src/WildcatMarketControllerFactory.sol                                       32             65            243
src/market/WildcatMarketWithdrawals.sol                                     33             20            132
src/WildcatArchController.sol                                               38             13            126
src/libraries/MathUtils.sol                                                 23             70            110
src/libraries/SafeCastLib.sol                                               33              1            106
src/libraries/FeeMath.sol                                                   19             58             97
src/libraries/StringQuery.sol                                               10             14             93
src/market/WildcatMarket.sol                                                17             16             91
src/interfaces/IWildcatMarketToken.sol                                       71              1             89
src/market/WildcatMarketConfig.sol                                          21             54             85
src/libraries/MarketState.sol                                                15             38             83
src/Escrow.sol                                                              14              3             76
src/interfaces/IMarketEventsAndErrors.sol                                    51             23             72
src/libraries/LibStoredInitCode.sol                                         15             38             69
src/interfaces/IWildcatMarketControllerFactory.sol                           12             60             62
src/libraries/FIFOQueue.sol                                                 14              4             62
src/interfaces/IWildcatMarketController.sol                                  22             69             60
src/MarketLens.sol                                                           14             56             59
src/market/WildcatMarketToken.sol                                           20             13             54
src/interfaces/IWildcatArchController.sol                                   39             13             47
src/interfaces/WildcatStructsAndEnums.sol                                    5              1             47
src/libraries/Errors.sol                                                     6             19             41
src/libraries/Withdrawal.sol                                                 7             16             37
src/ReentrancyGuard.sol                                                     10             44             33
src/interfaces/IWildcatMarketControllerEventsAndErrors.sol                   13             12             19
src/interfaces/IWildcatMarketFactory.sol                                      7              1             19
src/interfaces/IWildcatSanctionsSentinel.sol                                 7             20             18
src/libraries/BoolUtils.sol                                                  3              1             18
src/interfaces/ISanctionsSentinel.sol                                        7              4             16
src/interfaces/IERC20.sol                                                    9              1             13
src/interfaces/IERC20Metadata.sol                                            4              1              7
src/libraries/Chainalysis.sol                                                2              1              5
src/interfaces/IChainalysisSanctionsList.sol                                 1              1              4
------------------------------------------------------------------------------------------------------------
SUM:                                                                       723            956           2765
------------------------------------------------------------------------------------------------------------
```

## Withdrawals

Immutable config value: `withdrawalCycle` - seconds between withdrawal batches.

State:
```
uint104 pendingScaledWithdrawals;
uint32 nextWithdrawalTime = type(uint32).max;
uint128 reservedWithdrawals;
mapping(uint32 batchExpiry => WithdrawalBatch batch) withdrawalBatches;

struct WithdrawalBatch {
  // scaleFactor at the time the batch expired
  uint128 scaleFactor;
  // fraction of batch which was capitalized at time of batch expiry
  uint128 redemptionRate;
} 

Account {
  uint32 pendingWithdrawal;
  uint104 withdrawalAmount;
}
```

**note**: replace `accruedProtocolFees` with `outboundAssets`, use that in place of accrued fees for calculations of available assets.

Functions:
```
function updateGlobalWithdrawalStatus() {
  if (nextWithdrawalTime < block.timestamp) {

  }
}

liquidityCoverageRequired = (normalized supply) x (reserve ratio) + (accrued protocol fees) + withdrawalDebtsFinal + 


```


State:
- finalized withdrawals - withdrawal amounts from previous (expired) cycles
  * do not accrue interest
  * can not ever be counted towards liquidity in the market for any purpose

Types of liquidity availability:
- available for withdrawal by lenders
- available for borrower

a. Calculate interest for supply from last timestamp to the timestamp of the 

Lenders may request a withdrawal with `withdraw(uint256 amount)` where `amount` is a normalized (denominated in base asset) amount of wToken.
`scaledAmount = scale(amount, scaleFactor)` 

**1.** If a withdrawal batch exists and its expiry has elapsed:
  * calculate the checkpoint scaleFactor by accruing interest only until the moment of expiry, use it as the `scaleFactor` for the batch.
  * calculate the *normalized batch amount* as the product of the *scaled batch amount* and the checkpointed scale factor.
  * get the current available assets of the market (after accounting for all existing priority debts)
  * check if available assets are sufficient to cover normalized batch amount
    * If available assets >= *normalized batch amount*:
      * delete the *pending withdrawal batch*
      * set the status for the batch to:
        * redemption rate = 1
        * scale factor = checkpointed scale factor
      * increase the priority debt by *normalized batch amount*
    * If available assets < *normalized batch amount*:
      * set the status for the batch to:
        * redemption rate = (available assets) / (normalized batch amount)
        * scale factor = checkpointed scale factor
      * increase the priority debt by available assets
      * create a new withdrawal batch with:
        * expiry = timestamp + batch duration
        * scaled batch amount = scaled batch amount * (1 - redemption rate)

`realPending = normalize(pendingScaledWithdrawals, scaleFactor)`

**1.a.** If `realPending < availableAssets`



If no withdrawal batch exists globally, one is started.
The batch is assigned an expiry time `withdrawalCycle` seconds in the future.
`pendingScaledWithdrawals` is set to `scaledAmount`.


Until the withdrawal time, all pending withdrawals should accrue interest.
Once the withdrawal expiry is reached, the amount of assets actually able to 

For user:
To calculate 
