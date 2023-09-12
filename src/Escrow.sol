// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import './interfaces/IERC20.sol';

contract SanctionsEscrow {
  address public immutable sanctionsEscrowFactory;
	address public immutable account;
	address public immutable borrower;
	address[] internal _escrowedAssets;

	constructor() {
    sanctionsEscrowFactory = msg.sender;
		(account, borrower) = SanctionsEscrowFactory(msg.sender).getEscrowParameters();
	}

	function getEscrowedAssets()
		external
		view
		returns (address[] memory assets, uint256[] memory balances)
	{
		assets = _escrowedAssets;
		balances = new uint256[](assets.length);
		for (uint256 i = 0; i < assets.length; i++) {
			balances[i] = IERC20(assets[i]).balanceOf(address(this));
		}
	}

  function releaseAssets() external {
    
  }
}

address constant PlaceHolderAddress = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;

contract SanctionsEscrowFactory {
	error VaultNotRecognized();
	error NoPendingEscrowDeployment();
	event SanctionsEscrowCreated(address account, address borrower);

	bytes32 public immutable SanctionsEscrowInitCodeHash =
		keccak256(type(SanctionsEscrow).creationCode);

	// Temporary storage for escrow parameters, retrieved with getEscrowParameters()
	address internal sanctionsEscrowAccount = PlaceHolderAddress;
	address internal sanctionsEscrowBorrower = PlaceHolderAddress;

	function getEscrowParameters() external view returns (address account, address borrower) {
		if (account == PlaceHolderAddress) {
			revert NoPendingEscrowDeployment();
		}
		return (sanctionsEscrowAccount, sanctionsEscrowBorrower);
	}

	modifier onlyRegisteredVault() {
		// @todo - check msg.sender is a registered vault in arch-controller
		_;
	}

	function _deriveSalt(address account, address borrower) internal pure returns (bytes32 salt) {
		assembly {
			mstore(0, account)
			mstore(0x20, borrower)
			salt := keccak256(0, 0x40)
		}
	}

	function _computeEscrowAddress(bytes32 salt) internal view returns (address) {
		return
			address(
				uint160(
					uint256(
						keccak256(
							abi.encodePacked(bytes1(0xff), address(this), salt, SanctionsEscrowInitCodeHash)
						)
					)
				)
			);
	}

	function createSanctionsEscrow(
		address account,
		address borrower
	) external onlyRegisteredVault returns (address escrowContract) {
		bytes32 salt = _deriveSalt(account, borrower);
		escrowContract = _computeEscrowAddress(salt);
		if (escrowContract.code.length == 0) {
      sanctionsEscrowAccount = account;
      sanctionsEscrowBorrower = borrower;
			new SanctionsEscrow{ salt: salt }();
      sanctionsEscrowAccount = PlaceHolderAddress;
      sanctionsEscrowBorrower = PlaceHolderAddress;
		}
	}
}
