// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { MockERC20 } from 'solmate/test/utils/mocks/MockERC20.sol';
import 'src/WildcatVaultFactory.sol';
import 'src/WildcatVaultController.sol';
import './helpers/BaseERC20Test.sol';
import './helpers/MockController.sol';
import './shared/TestConstants.sol';

bytes32 constant DaiSalt = bytes32(uint256(1));

contract DebtTokenTest is BaseERC20Test {
	using VaultStateLib for VaultState;

	WildcatVaultFactory internal factory;
	WildcatVaultController internal controller;
	MockERC20 internal asset;
	address internal feeRecipient = address(0xfee);
	address internal borrower = address(this);

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
		factory = new WildcatVaultFactory();
		MockController mockController = new MockController(feeRecipient, address(factory));

		mockController.toggleParameterChecks();
		mockController.authorizeAll();
		controller = mockController;
		asset = new MockERC20('Token', 'TKN', 18);

		VaultParameters memory vaultParameters = VaultParameters({
			asset: address(asset),
			namePrefix: 'Wildcat ',
			symbolPrefix: 'WC',
			borrower: borrower,
			controller: address(controller),
			feeRecipient: feeRecipient,
			sentinel: address(0),
			maxTotalSupply: uint128(_maxAmount()),
			protocolFeeBips: DefaultProtocolFeeBips,
			annualInterestBips: 10000,
			delinquencyFeeBips: DefaultDelinquencyFee,
			withdrawalBatchDuration: 0,
			delinquencyGracePeriod: DefaultGracePeriod,
			liquidityCoverageRatio: DefaultLiquidityCoverage
		});
		token = IERC20Metadata(factory.deployVault(vaultParameters));
		_name = 'Wildcat Token';
		_symbol = 'WCTKN';
		_decimals = 18;
		// vm.warp(block.timestamp + 5008);
		// assertEq(WildcatMarket(address(token)).scaleFactor(), 2e27);
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
}
