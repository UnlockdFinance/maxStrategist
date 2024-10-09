// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import {IERC4626} from "./IERC4626.sol";

struct StrategyData {
    uint16 strategyDebtRatio;
    uint16 strategyPerformanceFee;
    uint48 strategyActivation;
    uint48 strategyLastReport;
    uint128 strategyMaxDebtPerHarvest;
    uint128 strategyMinDebtPerHarvest;
    uint128 strategyTotalUnrealizedGain;
    uint128 strategyTotalDebt;
    uint128 strategyTotalLoss;
    bool autoPilot;
}

/**
 * @notice IMaxApyVault contains the main interface for MaxApy V2 Vaults
 */
interface IMaxApyVault is IERC4626 {
    
    /// Roles
    function ADMIN_ROLE() external returns (uint256);

    function hasAnyRole(
        address user,
        uint256 roles
    ) external view returns (bool result);

    function strategies(
        address strategy
    ) external returns (StrategyData memory);

    function withdrawalQueue(uint256 index) external returns (address);

    function addStrategy(
        address newStrategy,
        uint256 strategyDebtRatio,
        uint256 strategyMaxDebtPerHarvest,
        uint256 strategyMinDebtPerHarvest,
        uint256 strategyPerformanceFee
    ) external;

    function removeStrategy(address strategy) external;

    function exitStrategy(address strategy) external;

    function updateStrategyData(
        address strategy,
        uint256 newDebtRatio,
        uint256 newMaxDebtPerHarvest,
        uint256 newMinDebtPerHarvest,
        uint256 newPerformanceFee
    ) external;
}
