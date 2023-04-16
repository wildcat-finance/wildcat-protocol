// pragma solidity >=0.8.17;

// import 'reference/interfaces/IERC20.sol';
// import './BaseHandler.sol';

// abstract contract ERC20Handler is BaseHandler {
// 	using LibAddressSet for AddressSet;

// 	IERC20 token;
// 	uint256 public ghost_mintSum;
// 	uint256 public ghost_burnSum;

// 	uint256 public ghost_zeroMints;
// 	uint256 public ghost_zeroBurns;
// 	uint256 public ghost_zeroTransfers;
// 	uint256 public ghost_zeroTransferFroms;

// 	constructor(IERC20 _token, string memory _label) BaseHandler(_label) {
// 		token = _token;
// 	}

//   // function _dealStartingBalance()

// 	function approve(
// 		uint256 actorSeed,
// 		uint256 spenderSeed,
// 		uint256 amount
// 	) public useActor(actorSeed) countCall('approve') {
// 		address spender = _actors.rand(spenderSeed);

// 		vm.prank(currentActor);
// 		token.approve(spender, amount);
// 	}

// 	function transfer(
// 		uint256 actorSeed,
// 		uint256 toSeed,
// 		uint256 amount
// 	) public useActor(actorSeed) countCall('transfer') {
// 		address to = _actors.rand(toSeed);

// 		amount = bound(amount, 0, token.balanceOf(currentActor));
// 		if (amount == 0) ghost_zeroTransfers++;

// 		vm.prank(currentActor);
// 		token.transfer(to, amount);
// 	}

// 	function transferFrom(
// 		uint256 actorSeed,
// 		uint256 fromSeed,
// 		uint256 toSeed,
// 		bool _approve,
// 		uint256 amount
// 	) public useActor(actorSeed) countCall('transferFrom') {
// 		address from = _actors.rand(fromSeed);
// 		address to = _actors.rand(toSeed);

// 		amount = bound(amount, 0, token.balanceOf(from));

// 		if (_approve) {
// 			vm.prank(from);
// 			token.approve(currentActor, amount);
// 		} else {
// 			amount = bound(amount, 0, token.allowance(currentActor, from));
// 		}
// 		if (amount == 0) ghost_zeroTransferFroms++;

// 		vm.prank(currentActor);
// 		token.transferFrom(from, to, amount);
// 	}

// 	function callSummary() public view virtual override {
// 		super.callSummary();
// 		console.log('-------------------');

// 		console.log('Zero withdrawals:', ghost_zeroBurns);
// 		console.log('Zero transferFroms:', ghost_zeroTransferFroms);
// 		console.log('Zero transfers:', ghost_zeroTransfers);
// 	}
// }
