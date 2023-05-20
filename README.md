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
  * can not ever be counted towards liquidity in the vault for any purpose

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