// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import { MockERC20 } from 'solmate/test/utils/mocks/MockERC20.sol';
import 'reference/WildcatVaultFactory.sol';
import 'reference/WildcatVaultController.sol';
import './helpers/BaseERC20Test.sol';

uint256 constant DefaultMaximumSupply = 100_000e18;
uint256 constant DefaultInterest = 1000;
uint256 constant DefaultPenaltyFee = 1000;
uint256 constant DefaultLiquidityCoverage = 2000;
uint256 constant DefaultGracePeriod = 2000;

bytes32 constant DaiSalt = bytes32(uint256(1));

contract DebtTokenTest is BaseERC20Test {
	WildcatVaultFactory internal factory;
	WildcatVaultController internal controller;
	MockERC20 internal asset;
	address internal feeRecipient = address(0xfee);
	address internal borrower = address(this);

	function setUp() public override {
		factory = new WildcatVaultFactory();
		controller = new WildcatVaultController(address(0xfee), address(factory));
		asset = new MockERC20('Token', 'TKN', 18);

		VaultParameters memory vaultParameters = VaultParameters({
      sentinel: address(0),
			borrower: borrower,
			asset: address(asset),
			controller: address(controller),
			namePrefix: 'Wildcat ',
			symbolPrefix: 'WC',
			maxTotalSupply: DefaultMaximumSupply,
			annualInterestBips: DefaultInterest,
			delinquencyFeeBips: 1000,
			delinquencyGracePeriod: DefaultGracePeriod,
			liquidityCoverageRatio: DefaultLiquidityCoverage,
			protocolFeeBips: 1000,
			feeRecipient: feeRecipient
		});
		token = IERC20Metadata(factory.deployVault(vaultParameters));
		_name = 'Wildcat Token';
		_symbol = 'WCTKN';
		_decimals = 18;
	}

	function _mint(address to, uint256 amount) internal override {
		asset.mint(address(this), amount);
		asset.approve(address(token), amount);
    hevm.prank(to);
		WildcatVaultToken(address(token)).depositUpTo(amount);
	}

	function _burn(address from, uint256 amount) internal override {
		hevm.prank(from);
		WildcatVaultToken(address(token)).withdraw(amount);
	}
}
