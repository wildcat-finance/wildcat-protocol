// // SPDX-License-Identifier: GPL-3.0-or-later
// pragma solidity >=0.8.20;

// import 'reference/interfaces/IERC20.sol';
// import './ERC20Handler.sol';

// uint256 constant BASE_TOKEN_SUPPLY = 100_000_000e18;

// abstract contract ERC20WrapperHandler is ERC20Handler {
// 	using LibAddressSet for AddressSet;
// 	IERC20 asset;

// 	constructor(IERC20 _token, IERC20 _asset) ERC20Handler(_token) {
// 		asset = _asset;
//     _mintBaseTokenToSelf(BASE_TOKEN_SUPPLY);
// 	}

// 	function _mintBaseTokenToSelf(uint256 amount) internal virtual;

//   function _convertToWrapped(uint256 baseAmount) internal virtual returns (uint256 wrappedAmount);

//   function _convertToBase(uint256 baseAmount) internal virtual returns (uint256 wrappedAmount);

//   function _executeDeposit(address to, uint256 amount) internal virtual;
//   function _executeWithdraw(address to, uint256 amount) internal virtual;

//   /**
//    * @dev Internal wrapper for mint tests
//    */
// 	// function _mint(address to, uint256 amount) internal virtual override {
//   //   asset.transfer(to, amount);
//   //   vm.prank(to);
//   //   _executeDeposit(to, amount);
//   // }

// 	// function _burn(address from, uint256 amount) internal virtual override {

//   // }

// 	// function _boundMint(uint256 amount) internal virtual override returns (uint256) {
//   //   return bound(amount, 0, _convertToWrapped(asset.balanceOf(address(this))));
//   // }


// 	// function _mint(address to, uint256 amount) internal virtual;

// 	// function _burn(address from, uint256 amount) internal virtual;

// 	// function _boundMint(uint256 amount) internal virtual returns (uint256);

// 	function deposit(
// 		uint256 amount
// 	) public virtual createActor countCall('deposit') {
// 		amount = bound(amount, 0, _convertToWrapped(asset.balanceOf(address(this))));

// 		if (amount == 0) ghost_zeroMints++;

//     asset.transfer(currentActor, amount);
//     vm.prank(currentActor);
//     _executeDeposit(currentActor, amount);

// 		ghost_mintSum += amount;
// 	}

// 	function withdraw(
// 		uint256 actorSeed,
// 		uint256 amount
// 	) public virtual useActor(actorSeed) countCall('withdraw') {
// 		amount = bound(amount, 0, token.balanceOf(currentActor));

// 		if (amount == 0) ghost_zeroBurns++;

//     vm.startPrank(currentActor);
// 		_executeWithdraw(currentActor, amount);
//     // asset.transfer(address(this), amount)

// 		ghost_burnSum += amount;
// 	}
// }
