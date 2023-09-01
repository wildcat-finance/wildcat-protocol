// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import './market/WildcatMarket.sol';
import './interfaces/IWildcatVaultFactory.sol';
import 'solady/auth/Ownable.sol';

struct TemporaryLiquidityCoverage {
	uint128 liquidityCoverageRatio;
	uint128 expiry;
}

contract WildcatVaultController is Ownable {
	using SafeCastLib for uint256;

	address public immutable factory;
	address public immutable feeRecipient;

	uint256 public constant MaximumDelinquencyGracePeriod = 1 days;
	uint256 public constant MinimumLiquidityCoverageRatio = 1000;
	uint256 public constant MinimumDelinquencyFee = 1000;

	error InvalidControllerParameter();
	error DelinquencyFeeTooLow();
	error DelinquencyGracePeriodTooHigh();
	error LiquidityCoverageRatioTooLow();
	error NotControlledVault();
	error CallerNotBorrower();
	error CallerNotFactory();
	error ExcessLiquidityCoverageStillActive();

	mapping(address => bool) public isControlledVault;

	mapping(address => TemporaryLiquidityCoverage) public temporaryExcessLiquidityCoverage;

	mapping(address => bool) internal _authorizedLenders;

	constructor(address _feeRecipient, address _factory) {
		_initializeOwner(msg.sender);
		feeRecipient = _feeRecipient;
		factory = _factory;
	}

	function authorizeLender(address lender) external virtual onlyOwner {
		_authorizedLenders[lender] = true;
	}

	function deauthorizeLender(address lender) external virtual onlyOwner {
		_authorizedLenders[lender] = false;
	}

	function isAuthorizedLender(address lender) external view virtual returns (bool) {
		return _authorizedLenders[lender];
	}

  function revokeAccountAuthorization(address vault, address lender) external virtual {
    if (!isControlledVault[vault]) {
			revertWithSelector(NotControlledVault.selector);
		}

		if (msg.sender != WildcatMarket(vault).borrower()) {
			revertWithSelector(CallerNotBorrower.selector);
		}

    WildcatMarket(vault).revokeAccountAuthorization(lender);
  }

	function getFinalVaultParameters(
		address /* deployer */,
		VaultParameters memory vaultParameters
	) public view virtual returns (VaultParameters memory) {
		// Doesn't do anything when called by the factory
		if (vaultParameters.controller != address(this)) {
			revert InvalidControllerParameter();
		}

		vaultParameters.feeRecipient = feeRecipient;

		vaultParameters.delinquencyGracePeriod = uint32(
			checkLte(
				vaultParameters.delinquencyGracePeriod,
				MaximumDelinquencyGracePeriod,
				DelinquencyGracePeriodTooHigh.selector
			)
		);

		vaultParameters.liquidityCoverageRatio = uint16(
			checkGte(
				vaultParameters.liquidityCoverageRatio,
				MinimumLiquidityCoverageRatio,
				LiquidityCoverageRatioTooLow.selector
			)
		);

		vaultParameters.delinquencyFeeBips = uint16(
			checkGte(
				vaultParameters.delinquencyFeeBips,
				MinimumDelinquencyFee,
				DelinquencyFeeTooLow.selector
			)
		);

		return vaultParameters;
	}

	function beforeDeployVault(
		address vault,
		address deployer,
		VaultParameters memory vaultParameters
	) external virtual returns (VaultParameters memory) {
		if (msg.sender != factory) {
			revertWithSelector(CallerNotFactory.selector);
		}

		isControlledVault[vault] = true;

		return getFinalVaultParameters(deployer, vaultParameters);
	}

	/**
	 * @dev Modify the interest rate for a vault.
	 * If the new interest rate is lower than the current interest rate,
	 * the liquidity coverage ratio is set to 90% for the next two weeks.
	 */
	function setAnnualInterestBips(address vault, uint256 annualInterestBips) external virtual {
		if (!isControlledVault[vault]) {
			revertWithSelector(NotControlledVault.selector);
		}

		if (msg.sender != WildcatMarket(vault).borrower()) {
			revertWithSelector(CallerNotBorrower.selector);
		}

		// If borrower is reducing the interest rate, increase the liquidity
		// coverage ratio for the next two weeks.
		if (annualInterestBips < WildcatMarket(vault).annualInterestBips()) {
			TemporaryLiquidityCoverage storage tmp = temporaryExcessLiquidityCoverage[vault];

			if (tmp.expiry == 0) {
				tmp.liquidityCoverageRatio = uint128(WildcatMarket(vault).liquidityCoverageRatio());

				// Require 90% liquidity coverage for the next 2 weeks
				WildcatMarket(vault).setLiquidityCoverageRatio(9000);
			}

			tmp.expiry = uint128(block.timestamp + 2 weeks);
		}

		WildcatMarket(vault).setAnnualInterestBips(uint256(annualInterestBips).toUint16());
	}

	function resetLiquidityCoverage(address vault) external virtual {
		TemporaryLiquidityCoverage memory tmp = temporaryExcessLiquidityCoverage[vault];
		if (block.timestamp < tmp.expiry) {
			revertWithSelector(ExcessLiquidityCoverageStillActive.selector);
		}
		WildcatMarket(vault).setLiquidityCoverageRatio(uint256(tmp.liquidityCoverageRatio).toUint16());
		delete temporaryExcessLiquidityCoverage[vault];
	}

	function checkGte(
		uint256 value,
		uint256 defaultValue,
		bytes4 errorSelector
	) internal pure returns (uint256) {
		if (value == 0) return defaultValue;
		if (value < defaultValue) revertWithSelector(errorSelector);
		return value;
	}

	function checkLte(
		uint256 value,
		uint256 defaultValue,
		bytes4 errorSelector
	) internal pure returns (uint256) {
		if (value == 0) return defaultValue;
		if (value > defaultValue) revertWithSelector(errorSelector);
		return value;
	}
}
