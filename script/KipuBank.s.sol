// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {KipuBank} from "../src/KipuBank.sol";

contract KipuBankScript is Script {
    KipuBank public kipuBank;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Get deployment parameters from environment variables
        // Network-specific addresses (update these based on deployment network)
        address uniswapV2Router = vm.envAddress("UNISWAP_V2_ROUTER_SEPOLIA");
        address usdcAddress = vm.envAddress("USDC_SEPOLIA");

        // Bank configuration
        uint256 bankCapUsd = vm.envUint("BANK_CAP_USD");
        uint256 withdrawalLimitUsd = vm.envUint("WITHDRAWAL_LIMIT_USD");

        // Deploy KipuBank
        kipuBank = new KipuBank(withdrawalLimitUsd, bankCapUsd, usdcAddress, uniswapV2Router);

        vm.stopBroadcast();
    }
}
