// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import {
    DAI_POLYGON,
    USDCE_POLYGON
} from "./Constants.sol";

uint256 constant _1_USDC = 1e6;
uint256 constant _1_USDCE = 1e6;
uint256 constant _1_USDT = 1e6;
uint256 constant _1_DAI = 1 ether;

function getTokensList() pure returns (address[] memory) {
        address[] memory tokens = new address[](2);
        tokens[0] = DAI_POLYGON;
        tokens[1] = USDCE_POLYGON;
        return tokens;
}
