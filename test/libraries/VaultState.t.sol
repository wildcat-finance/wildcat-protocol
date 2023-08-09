// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.20;

// import "forge-std/Test.sol";
// import "reference/libraries/Withdrawal.sol";
// import "solmate/test/utils/mocks/MockERC20.sol";

// contract SimpleStateHandler {
//   VaultState internal _state;
//   MockERC20 internal asset = new MockERC20("Token", "TKN", 18);


//   uint128 public ghost_depositSum;
//   uint128 public ghost_withdrawSum;

//   function availableAssets() internal view returns (uint256) {
//     return asset.balanceOf(address(this));
//   }

//   function deposit(uint128 amount) external {
//     asset.mint(address(this), amount);
    
//   }

//   function accrueProtocolFees()
// }

// contract WithdrawalTest is Test {
//   WithdrawalData internal _withdrawalData;

//   function test_availableLiquidityForBatch(
//     uint128 reservedAssets,
//     uint128 scaledPendingWithdrawals,
//   ) external {
//     VaultState memory state;
//     state.scaledPendingWithdrawals = 1e18;
//     state.reservedAssets 
//   }
// }