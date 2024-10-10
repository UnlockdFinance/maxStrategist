// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {Initializable} from "./lib/Initializable.sol";
import {IMaxApyVault, StrategyData} from "./interfaces/IMaxApyVault.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";

import "forge-std/console.sol";

/**
 * @title MaxStrategist
 * @dev This is an internal contract to manage the maxApyVaultStrategies harvest in an atomic way.
 */
contract MaxStrategist is Initializable, OwnableRoles {
    /*//////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////*/
    error AddStrategyFailed();
    error CantReceiveETH();
    error Fallback();

    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/
    // Struct to encapsulate information about an individual NFT transfer.
    // It needs the strategy address that will harvest from,
    // who will be the harvester,
    // the expected balance after the harvest,
    // the minimum output after the investment,
    struct StratData {
        address strategyAddress;
        uint256 strategyDebtRatio;
        uint256 strategyMaxDebtPerHarvest;
        uint256 strategyMinDebtPerHarvest;
        uint256 strategyPerformanceFee;
    }

    // Struct to encapsulate information about an individual NFT transfer.
    // It needs the strategy address that will harvest from,
    // who will be the harvester,
    // the expected balance after the harvest,
    // the minimum output after the investment,
    struct HarvestData {
        address strategyAddress;
        address harvester;
        uint256 minExpectedBalance;
        uint256 minOutputAfterInvestment;
        uint256 deadline;
    }

    ////////////////////////////////////////////////////////////////
    ///                        CONSTANTS                         ///
    ////////////////////////////////////////////////////////////////
    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant KEEPER_ROLE = _ROLE_1;

    ////////////////////////////////////////////////////////////////
    ///                       MODIFIERS                          ///
    ////////////////////////////////////////////////////////////////
    modifier checkRoles(uint256 roles) {
        _checkRoles(roles);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Constructor to set the initial state of the contract.
     * @param keepers The address of the CryptoPunks contract.
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

        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                    Fallback and Receive Functions
    //////////////////////////////////////////////////////////////*/
    // Explicitly reject any Ether sent to the contract
    fallback() external payable {
        revert Fallback();
    }

    // Explicitly reject any Ether transfered to the contract
    receive() external payable {
        revert CantReceiveETH();
    }

    /*//////////////////////////////////////////////////////////////
                          LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Orchestrates a batch add strategy for the maxapy protocol.
     * @param strategies An array of strategy values to add to
     * the strategy to the vault.
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
     * @dev Orchestrates a batch add strategy for the maxapy protocol.
     * @param harvests An array of strategy values to add to
     * the strategy to the vault.
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
                harvests[i].harvester,
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
