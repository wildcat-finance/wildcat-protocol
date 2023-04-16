// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.7;

// // import { MockERC20 } from "../../lib/erc20/contracts/test/mocks/MockERC20.sol";

// import { console } from 'forge-std/console.sol';
// import { StdUtils } from 'forge-std/StdUtils.sol';
// import { Vm } from 'forge-std/Vm.sol';

// import { IWildcatVault } from 'reference/interfaces/IWildcatVault.sol';
// import 'solmate/test/utils/mocks/MockERC20.sol';
// import './BaseHandler.sol';

// contract UnboundedLpHandler is BaseHandler {
// 	address public currentLp;

// 	// uint256 public numLps;
// 	// uint256 public maxLps;

// 	// address[] public lps;

// 	// mapping(address => bool) public isLp;

// 	IWildcatVault public token;

// 	MockERC20 public asset;

// 	uint256 public sumBalance;

// 	constructor(
// 		address asset_,
// 		address token_,
// 		uint256 _maxActors
// 	) BaseHandler('unboundLp', _maxActors) {
// 		asset = MockERC20(asset_);
// 		token = IWildcatVault(token_);
// 		_actors.add(address(1));
// 	}

// 	function _deposit(uint256 assets) internal {
// 		asset.mint(currentLp, assets);

// 		asset.approve(address(token), assets);

// 		uint256 shares = token.deposit(assets, currentLp);

// 		sumBalance += shares;
// 	}

// 	function addActor(address lp) public virtual {
// 		_countCall('unboundedLp.addLp');
// 		_addActor(true);
// 	}

// 	function deposit(
// 		uint256 assets,
// 		uint256 lpIndex
// 	) public virtual useActor(lpIndex) countCall('deposit') {
// 		_deposit(assets);
// 	}

// 	function transfer(
// 		uint256 assets,
// 		address receiver,
// 		uint256 lpIndex,
// 		uint256 receiverLpIndex
// 	)
// 		public
// 		virtual
// 		useTwoActors(lpIndex, receiver, receiverLpIndex)
// 		countCall('transfer')
// 	{
// 		token.transfer(secondActor, assets);
// 	}
// }

// contract BoundedLpHandler is UnboundedLpHandler {
// 	constructor(
// 		address asset_,
// 		address token_,
// 		uint256 _maxActors
// 	) UnboundedLpHandler(asset_, token_, _maxActors) {
// 		label = 'boundedLp';
// 	}

// 	function addLp(address lp) public override {
// 		_countCall('boundedLp.addLp');

// 		if (lp == address(0)) {
// 			_countCall('boundedLp.addLp.zeroAddress');
// 			return;
// 		}

// 		super.addLp(lp);
// 	}

// 	function deposit(uint256 assets, uint256 lpIndex) public override {
// 		_countCall('boundedLp.deposit');

// 		uint256 totalSupply = token.totalSupply();

// 		uint256 minDeposit = totalSupply == 0
// 			? 1
// 			: token.totalAssets() / totalSupply + 1;

// 		assets = bound(assets, minDeposit, 1e36);

// 		super.deposit(assets, lpIndex);
// 	}

// 	function transfer(
// 		uint256 assets,
// 		address receiver,
// 		uint256 lpIndex,
// 		uint256 receiverLpIndex
// 	) public override {
// 		_countCall('boundedLp.transfer');

// 		// If receiver is address(0), use an existing LP address.
// 		if (receiver == address(0)) {
// 			receiver = _actors.rand(receiverLpIndex);
// 		}

// 		assets = bound(assets, 0, token.balanceOf(currentLp));

// 		super.transfer(assets, receiver, lpIndex, receiverLpIndex);
// 	}
// }
