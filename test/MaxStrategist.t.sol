// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "../src/MaxStrategist.sol";

contract MaxHarvesterTest is Test {
    MaxStrategist maxStrategist;

    address internal admin = address(0x123);
    address internal keeper1 = address(0x456);
    address internal keeper2 = address(0x789);
    address internal nonKeeper = address(0xabc);

    function setUp() public {
        address[] memory keepers = new address[](2);
        keepers[0] = keeper1;
        keepers[1] = keeper2;

        maxStrategist = new MaxStrategist(admin, keepers);
    }

    function testAdminRole() public view {
        assertTrue(maxStrategist.hasAnyRole(admin, maxStrategist.ADMIN_ROLE()));
        assertFalse(maxStrategist.hasAnyRole(keeper1, maxStrategist.ADMIN_ROLE()));
    }

    function testKeeperRole() public view {
        assertTrue(maxStrategist.hasAnyRole(keeper1, maxStrategist.KEEPER_ROLE()));
        assertTrue(maxStrategist.hasAnyRole(keeper2, maxStrategist.KEEPER_ROLE()));
        assertFalse(maxStrategist.hasAnyRole(nonKeeper, maxStrategist.KEEPER_ROLE()));
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
}
