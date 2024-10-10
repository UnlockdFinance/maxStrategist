// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./helpers/Constants.sol";
import {MaxStrategist} from "../src/MaxStrategist.sol";
import {MaxApyVault} from "./mocks/MaxApyVault.sol";
import {IMaxApyVault, StrategyData} from "../src/interfaces/IMaxApyVault.sol";
import {IStrategy} from "../src/interfaces/IStrategy.sol";
import {IERC20Metadata} from "../src/interfaces/IERC20Metadata.sol";
import {getTokensList} from "./helpers/Tokens.sol";
import {IStrategy} from "../src/interfaces/IStrategy.sol";

contract MaxStrategistTest is Test {
    MaxStrategist maxStrategist;

    address admin = ADMIN;
    address keeper = ALLOCATOR;
    address nonKeeper = address(0xabc);
    address treasury = address(0xdef);

    MaxApyVault maxApyVault;
    IMaxApyVault vault;

    IStrategy DAILenderStrategy;
    IStrategy DAIStrategy;

    uint256 internal polygonFork;

    function setUp() public {
        polygonFork = vm.createFork(vm.envString("RPC_POLYGON"));
        vm.rollFork(polygonFork, 62_778_308);
        vm.selectFork(polygonFork);

        address[] memory tokens = getTokensList();

        vm.deal({account: admin, newBalance: 1000 ether});
        for (uint256 i; i < tokens.length; ) {
            deal({
                token: tokens[i],
                to: admin,
                give: 1000 * 10 ** IERC20Metadata(tokens[i]).decimals()
            });
            unchecked {
                ++i;
            }
        }

        vm.startPrank({msgSender: admin, txOrigin: admin});

        address[] memory keepers = new address[](1);
        keepers[0] = keeper;

        maxApyVault = MaxApyVault(MAXAPY_POLYGON_VAULT);
        vault = IMaxApyVault(address(maxApyVault));

        maxStrategist = new MaxStrategist(admin, keepers);
        vault.grantRoles(address(maxStrategist), vault.ADMIN_ROLE());

        DAILenderStrategy = IStrategy(MAXAPY_POLYGON_YVAULT_DAI_LENDER);
        DAILenderStrategy.grantRoles(address(maxStrategist), DAILenderStrategy.KEEPER_ROLE());

        DAIStrategy = IStrategy(MAXAPY_POLYGON_YVAULT_DAI);
        DAIStrategy.grantRoles(address(maxStrategist), DAILenderStrategy.KEEPER_ROLE());

        assertEq(
            vault.hasAnyRole(address(maxStrategist), vault.ADMIN_ROLE()),
            true
        );
        assertEq(
            DAILenderStrategy.hasAnyRole(address(maxStrategist), DAILenderStrategy.KEEPER_ROLE()),
            true
        );
        vm.label(address(maxStrategist), "MaxStrategist");
        vm.label(address(maxApyVault), "MaxApyVault");
        vm.label(address(DAILenderStrategy), "Strategy");
    }

    function testAdminRole() public view {
        assertTrue(maxStrategist.hasAnyRole(admin, maxStrategist.ADMIN_ROLE()));
        assertFalse(
            maxStrategist.hasAnyRole(keeper, maxStrategist.ADMIN_ROLE())
        );
    }

    function testKeeperRole() public view {
        assertTrue(
            maxStrategist.hasAnyRole(keeper, maxStrategist.KEEPER_ROLE())
        );
        assertFalse(
            maxStrategist.hasAnyRole(nonKeeper, maxStrategist.KEEPER_ROLE())
        );
    }

    function testFallbackRevert() public {
        vm.expectRevert(MaxStrategist.Fallback.selector);
        (bool success, ) = address(maxStrategist).call{value: 1 ether}("");
        assertFalse(success);
    }

    function testReceiveRevert() public {
        vm.expectRevert(MaxStrategist.CantReceiveETH.selector);
        payable(address(maxStrategist)).transfer(1 ether);
    }

    function testAddStrategy_single() public {
        MaxStrategist.StratData[]
            memory stratData = new MaxStrategist.StratData[](1);
        stratData[0] = MaxStrategist.StratData({
            strategyAddress: address(0),
            strategyDebtRatio: 2000,
            strategyMaxDebtPerHarvest: type(uint72).max,
            strategyMinDebtPerHarvest: 0,
            strategyPerformanceFee: 200
        });

        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        maxStrategist.batchAddStrategies(vault, stratData);
        vm.stopPrank();

        vm.startPrank(keeper);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        maxStrategist.batchAddStrategies(vault, stratData);

        stratData[0].strategyAddress = address(DAILenderStrategy);
        maxStrategist.batchAddStrategies(vault, stratData);
        StrategyData memory strategyData = vault.strategies(address(DAILenderStrategy));

        assertEq(
            stratData[0].strategyDebtRatio,
            strategyData.strategyDebtRatio
        );
        assertEq(
            stratData[0].strategyMaxDebtPerHarvest,
            strategyData.strategyMaxDebtPerHarvest
        );
        assertEq(
            stratData[0].strategyMinDebtPerHarvest,
            strategyData.strategyMinDebtPerHarvest
        );
        assertEq(
            stratData[0].strategyPerformanceFee,
            strategyData.strategyPerformanceFee
        );
        vm.stopPrank();
    }

    function testAddStrategy_multiple() public {
        MaxStrategist.StratData[]
            memory stratData = new MaxStrategist.StratData[](2);
        stratData[0] = MaxStrategist.StratData({
            strategyAddress: address(0),
            strategyDebtRatio: 2000,
            strategyMaxDebtPerHarvest: type(uint72).max,
            strategyMinDebtPerHarvest: 0,
            strategyPerformanceFee: 200
        });
         stratData[1] = MaxStrategist.StratData({
            strategyAddress: address(DAIStrategy),
            strategyDebtRatio: 4000,
            strategyMaxDebtPerHarvest: type(uint72).max,
            strategyMinDebtPerHarvest: 0,
            strategyPerformanceFee: 300
        });

        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        maxStrategist.batchAddStrategies(vault, stratData);
        vm.stopPrank();

        vm.startPrank(keeper);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        maxStrategist.batchAddStrategies(vault, stratData);

        stratData[0].strategyAddress = address(DAILenderStrategy);
        maxStrategist.batchAddStrategies(vault, stratData);
        StrategyData memory strategyData = vault.strategies(address(DAILenderStrategy));

        assertEq(
            stratData[0].strategyDebtRatio,
            strategyData.strategyDebtRatio
        );
        assertEq(
            stratData[0].strategyMaxDebtPerHarvest,
            strategyData.strategyMaxDebtPerHarvest
        );
        assertEq(
            stratData[0].strategyMinDebtPerHarvest,
            strategyData.strategyMinDebtPerHarvest
        );
        assertEq(
            stratData[0].strategyPerformanceFee,
            strategyData.strategyPerformanceFee
        );

        strategyData = vault.strategies(address(DAIStrategy));

        assertEq(
            stratData[1].strategyDebtRatio,
            strategyData.strategyDebtRatio
        );
        assertEq(
            stratData[1].strategyMaxDebtPerHarvest,
            strategyData.strategyMaxDebtPerHarvest
        );
        assertEq(
            stratData[1].strategyMinDebtPerHarvest,
            strategyData.strategyMinDebtPerHarvest
        );
        assertEq(
            stratData[1].strategyPerformanceFee,
            strategyData.strategyPerformanceFee
        );
        vm.stopPrank();
    }

    function testRemoveStrategy_single() public {
        MaxStrategist.StratData[]
            memory stratData = new MaxStrategist.StratData[](1);
        stratData[0] = MaxStrategist.StratData({
            strategyAddress: address(DAILenderStrategy),
            strategyDebtRatio: 2000,
            strategyMaxDebtPerHarvest: type(uint72).max,
            strategyMinDebtPerHarvest: 0,
            strategyPerformanceFee: 200
        });

        vm.startPrank(keeper);
        maxStrategist.batchAddStrategies(vault, stratData);
        StrategyData memory strategyData = vault.strategies(address(DAILenderStrategy));

        assertEq(
            stratData[0].strategyDebtRatio,
            strategyData.strategyDebtRatio
        );
        assertEq(
            stratData[0].strategyMaxDebtPerHarvest,
            strategyData.strategyMaxDebtPerHarvest
        );
        assertEq(
            stratData[0].strategyMinDebtPerHarvest,
            strategyData.strategyMinDebtPerHarvest
        );
        assertEq(
            stratData[0].strategyPerformanceFee,
            strategyData.strategyPerformanceFee
        );

        vm.stopPrank();
        MaxStrategist.HarvestData[]
            memory harvestData = new MaxStrategist.HarvestData[](1);
        harvestData[0] = MaxStrategist.HarvestData({
            strategyAddress: address(0),
            harvester: keeper,
            minExpectedBalance: 0,
            minOutputAfterInvestment: 0,
            deadline: block.timestamp
        });

        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        maxStrategist.batchRemoveStrategies(vault, harvestData);
        vm.stopPrank();

        vm.startPrank(keeper);
        vm.expectRevert(abi.encodeWithSignature("StrategyNotActive()"));
        maxStrategist.batchRemoveStrategies(vault, harvestData);

        harvestData[0].strategyAddress = address(DAILenderStrategy);
        harvestData[0].harvester = keeper;
        assertEq(
            vault.hasAnyRole(address(DAILenderStrategy), vault.STRATEGY_ROLE()),
            true
        );
        maxStrategist.batchRemoveStrategies(vault, harvestData);

        strategyData = vault.strategies(address(DAILenderStrategy));
        assertEq(
            vault.hasAnyRole(address(DAILenderStrategy), vault.STRATEGY_ROLE()),
            false
        );
        vm.stopPrank();
    }

    function testRemoveStrategy_multiple() public {
        MaxStrategist.StratData[]
            memory stratData = new MaxStrategist.StratData[](2);
        stratData[0] = MaxStrategist.StratData({
            strategyAddress: address(DAILenderStrategy),
            strategyDebtRatio: 2000,
            strategyMaxDebtPerHarvest: type(uint72).max,
            strategyMinDebtPerHarvest: 0,
            strategyPerformanceFee: 200
        });
         stratData[1] = MaxStrategist.StratData({
            strategyAddress: address(DAIStrategy),
            strategyDebtRatio: 4000,
            strategyMaxDebtPerHarvest: type(uint72).max,
            strategyMinDebtPerHarvest: 0,
            strategyPerformanceFee: 300
        });

        vm.startPrank(keeper);
        maxStrategist.batchAddStrategies(vault, stratData);
        vm.stopPrank();

        MaxStrategist.HarvestData[]
            memory harvestData = new MaxStrategist.HarvestData[](2);
        harvestData[0] = MaxStrategist.HarvestData({
            strategyAddress: address(DAILenderStrategy),
            harvester: keeper,
            minExpectedBalance: 0,
            minOutputAfterInvestment: 0,
            deadline: block.timestamp
        });
        harvestData[1] = MaxStrategist.HarvestData({
            strategyAddress: address(DAIStrategy),
            harvester: keeper,
            minExpectedBalance: 0,
            minOutputAfterInvestment: 0,
            deadline: block.timestamp
        });

        vm.startPrank(keeper);
        assertEq(
            vault.hasAnyRole(address(DAILenderStrategy), vault.STRATEGY_ROLE()),
            true
        );
        assertEq(
            vault.hasAnyRole(address(DAIStrategy), vault.STRATEGY_ROLE()),
            true
        );
        maxStrategist.batchRemoveStrategies(vault, harvestData);

        assertEq(
            vault.hasAnyRole(address(DAILenderStrategy), vault.STRATEGY_ROLE()),
            false
        );
        assertEq(
            vault.hasAnyRole(address(DAIStrategy), vault.STRATEGY_ROLE()),
            false
        );

        vm.stopPrank();
    }
}
