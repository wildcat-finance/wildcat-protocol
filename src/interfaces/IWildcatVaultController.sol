// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { VaultParameters } from "./WildcatStructsAndEnums.sol";

interface IWildcatVaultController {
	error NewOwnerIsZeroAddress();

	error NoHandoverRequest();

	error Unauthorized();

	event OwnershipHandoverCanceled(address);

	event OwnershipHandoverRequested(address);

	event OwnershipTransferred(address, address);

	function cancelOwnershipHandover() external payable;

	function completeOwnershipHandover(address pendingOwner) external payable;

	function factory() external view returns (address);

	function feeRecipient() external view returns (address);

	function getFinalVaultParameters(
		address,
		VaultParameters calldata vaultParameters
	) external view returns (VaultParameters memory);

	function beforeDeployVault(
		address vault,
		address deployer,
		VaultParameters calldata vaultParameters
	) external returns (VaultParameters memory);

	function isAuthorizedLender(address) external view returns (bool);

	function owner() external view returns (address result);

	function ownershipHandoverExpiresAt(address pendingOwner) external view returns (uint256 result);

	function ownershipHandoverValidFor() external view returns (uint64);

	function reduceInterestRate(address vault, uint256 amount) external;

	function renounceOwnership() external payable;

	function requestOwnershipHandover() external payable;

	function resetLiquidityCoverage(address vault) external;

	function temporaryExcessLiquidityCoverage(
		address
	) external view returns (uint128 liquidityCoverageRatio, uint128 expiry);

	function transferOwnership(address newOwner) external payable;

	function vaults(address) external view returns (bool);
}
