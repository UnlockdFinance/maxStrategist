// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {IMaxApyVault, StrategyData} from "./interfaces/IMaxApyVault.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";

/**
 * @title MaxStrategist
 * @dev This is an internal contract to manage the maxApyVaultStrategies harvest in an atomic way.
 * @custom:security-contact security@example.com
 */
contract MaxStrategist is OwnableRoles {
    /*//////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////*/
    error AddStrategyFailed();
    error CantReceiveETH();
    error Fallback();

    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Struct to encapsulate information about the strategy to add.
     * @param strategyAddress The address of the strategy.
     * @param strategyDebtRatio The debt ratio for the strategy.
     * @param strategyMaxDebtPerHarvest The maximum debt per harvest for the strategy.
     * @param strategyMinDebtPerHarvest The minimum debt per harvest for the strategy.
     * @param strategyPerformanceFee The performance fee for the strategy.
     */
    struct StratData {
        address strategyAddress;
        uint256 strategyDebtRatio;
        uint256 strategyMaxDebtPerHarvest;
        uint256 strategyMinDebtPerHarvest;
        uint256 strategyPerformanceFee;
    }

    /**
     * @dev Struct to encapsulate information about an individual harvest.
     * @param strategyAddress The address of the strategy to harvest from.
     * @param minExpectedBalance The minimum expected balance after the harvest.
     * @param minOutputAfterInvestment The minimum output after the investment.
     * @param deadline The deadline for the harvest operation.
     */
    struct HarvestData {
        address strategyAddress;
        uint256 minExpectedBalance;
        uint256 minOutputAfterInvestment;
        uint256 deadline;
    }

    ////////////////////////////////////////////////////////////////
    ///                        CONSTANTS                         ///
    ////////////////////////////////////////////////////////////////
    // ROLES
    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant KEEPER_ROLE = _ROLE_1;
    // ACTORS
    address public constant DEFAULT_HARVESTER = address(0);

    ////////////////////////////////////////////////////////////////
    ///                       MODIFIERS                          ///
    ////////////////////////////////////////////////////////////////
    /**
     * @dev Modifier to check if the caller has the required roles.
     * @param roles The roles to check.
     */
    modifier checkRoles(uint256 roles) {
        _checkRoles(roles);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Constructor to set the initial state of the contract.
     * @param admin The address of the admin.
     * @param keepers An array of addresses for the keepers that will call the contract functions.
     */
    constructor(address admin, address[] memory keepers) {
        // loop to add the keepers to a mapping
        _initializeOwner(admin);
        _grantRoles(admin, ADMIN_ROLE);

        uint256 length = keepers.length;

        // Iterate through each Keeper in the array in order to grant roles.
        for (uint256 i = 0; i < length; ) {
            _grantRoles(keepers[i], KEEPER_ROLE);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    Fallback and Receive Functions
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Fallback function to reject any Ether sent to the contract.
     */
    fallback() external payable {
        revert Fallback();
    }

    /**
     * @dev Receive function to reject any Ether transferred to the contract.
     */
    receive() external payable {
        revert CantReceiveETH();
    }

    /*//////////////////////////////////////////////////////////////
                          LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Orchestrates a batch add strategy for the maxapy protocol.
     * @param vault The MaxApyVault contract instance.
     * @param strategies An array of strategy values to add to the vault.
     */
    function batchAddStrategies(
        IMaxApyVault vault,
        StratData[] memory strategies 
    ) external checkRoles(KEEPER_ROLE) {
        uint256 length = strategies.length;

        // Iterate through each strategy in the array in order to add the strategy .
        for (uint i = 0; i < length; ) {
            vault.addStrategy(
                strategies[i].strategyAddress,
                strategies[i].strategyDebtRatio,
                strategies[i].strategyMaxDebtPerHarvest,
                strategies[i].strategyMinDebtPerHarvest,
                strategies[i].strategyPerformanceFee
            );
            // Use unchecked block to bypass overflow checks for efficiency.
            unchecked {
                i++;
            }
        }
    }

    /**
     * @dev Orchestrates a batch remove strategy for the maxapy protocol.
     * @param vault The MaxApyVault contract instance.
     * @param harvests An array of harvest data for strategies to remove from the vault.
     */
    function batchRemoveStrategies(
        IMaxApyVault vault,
        HarvestData[] calldata harvests
    ) external checkRoles(KEEPER_ROLE) {
        uint256 length = harvests.length;

        // Iterate through each strategy in the array in order to call the harvest.
        for (uint i = 0; i < length; ) {
            address strategyAddress = harvests[i].strategyAddress;

            StrategyData memory strategyData = vault.strategies(
                strategyAddress
            );

            vault.updateStrategyData(
                strategyAddress,
                0,
                strategyData.strategyMaxDebtPerHarvest,
                strategyData.strategyMinDebtPerHarvest,
                strategyData.strategyPerformanceFee
            );

            IStrategy strategy = IStrategy(strategyAddress);
            strategy.harvest(
                harvests[i].minExpectedBalance,
                harvests[i].minOutputAfterInvestment,
                DEFAULT_HARVESTER,
                harvests[i].deadline
            );

            vault.exitStrategy(strategyAddress);

            // Use unchecked block to bypass overflow checks for efficiency.
            unchecked {
                i++;
            }
        }
    }
}
