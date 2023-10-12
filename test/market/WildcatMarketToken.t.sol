// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { MockERC20 } from 'solmate/test/utils/mocks/MockERC20.sol';
import { BaseERC20Test } from '../helpers/BaseERC20Test.sol';
import '../shared/TestConstants.sol';
import '../shared/Test.sol';

bytes32 constant DaiSalt = bytes32(uint256(1));

contract WildcatMarketTokenTest is BaseERC20Test, Test {
  using VaultStateLib for VaultState;

  // WildcatVaultFactory internal factory;
  // WildcatVaultController internal controller;
  MockERC20 internal asset;
  address internal feeRecipient = address(0xfee);
  address internal borrower = address(this);

  function bound(
    uint x,
    uint min,
    uint max
  ) internal view virtual override(StdUtils, Test) returns (uint256 result) {
    return Test.bound(x, min, max);
  }

  function _maxAmount() internal override returns (uint256) {
    return uint256(type(uint104).max);
  }

  function _minAmount() internal override returns (uint256 min) {
    min = divUp(WildcatMarket(address(token)).scaleFactor(), RAY);
  }

  function divUp(uint256 x, uint256 d) internal pure returns (uint256 z) {
    /// @solidity memory-safe-assembly
    assembly {
      if iszero(d) {
        // Store the function selector of `DivFailed()`.
        mstore(0x00, 0x65244e4e)
        // Revert with (offset, size).
        revert(0x1c, 0x04)
      }
      z := add(iszero(iszero(mod(x, d))), div(x, d))
    }
  }

  function setUp() public override {
    asset = new MockERC20('Token', 'TKN', 18);

    VaultParameters memory vaultParameters = VaultParameters({
      asset: address(asset),
      namePrefix: 'Wildcat ',
      symbolPrefix: 'WC',
      borrower: borrower,
      controller: controllerFactory.computeControllerAddress(borrower),
      feeRecipient: feeRecipient,
      sentinel: address(sanctionsSentinel),
      maxTotalSupply: uint128(_maxAmount()),
      protocolFeeBips: DefaultProtocolFeeBips,
      annualInterestBips: 10000,
      delinquencyFeeBips: DefaultDelinquencyFee,
      withdrawalBatchDuration: 0,
      delinquencyGracePeriod: DefaultGracePeriod,
      reserveRatioBips: DefaultReserveRatio
    });
    deployControllerAndVault(vaultParameters, true, true);
    token = IERC20Metadata(address(vault));
    _name = 'Wildcat Token';
    _symbol = 'WCTKN';
    _decimals = 18;
    // vm.warp(block.timestamp + 5008);
    // assertEq(WildcatMarket(address(token)).scaleFactor(), 2e27);
  }

  function testCtrl() external {
    assertEq(
      address(controller),
      controllerFactory.computeControllerAddress(borrower),
      'bad controller address'
    );
    assertTrue(MockController(address(controller)).AUTH_ALL(), 'bad auth');
    assertEq(
      controllerFactory.controllerInitCodeHash(),
      uint256(keccak256(type(MockController).creationCode)),
      'bad init code hash'
    );
    console2.log(vault.name());
  }

  // function _assertTokenAmountEq(uint256 expected, uint256 actual) internal virtual override {
  // 	assertEq(expected, actual);
  // }

  function _mint(address to, uint256 amount) internal override {
    require(amount <= _maxAmount(), 'amount too large');
    vm.startPrank(to);
    asset.mint(to, amount);
    asset.mint(to, amount);
    // vm.startPrank(to);
    asset.approve(address(token), amount);
    WildcatMarket(address(token)).depositUpTo(amount);
    WildcatMarket(address(token)).transfer(to, amount);
    vm.stopPrank();
  }

  function _burn(address from, uint256 amount) internal override {
    vm.prank(from);
    WildcatMarket(address(token)).queueWithdrawal(amount);
    WildcatMarket(address(token)).executeWithdrawal(from, uint32(block.timestamp));
  }

  function testTransferNullAmount() external {
    vm.expectRevert(IVaultEventsAndErrors.NullTransferAmount.selector);
    token.transfer(address(1), 0);
  }

  function testTransferFromNullAmount() external {
    vm.expectRevert(IVaultEventsAndErrors.NullTransferAmount.selector);
    token.transferFrom(address(0), address(1), 0);
  }
}
