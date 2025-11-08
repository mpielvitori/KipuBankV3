// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console2} from "forge-std/Script.sol";
import {KipuBank} from "../src/KipuBank.sol";

interface IRouter {
    function factory() external view returns (address);
    function WETH() external view returns (address);
}

contract KipuBankScript is Script {
    KipuBank public kipuBank;

    function setUp() public {}

    function run() public {
        // Read environment variables for Mainnet
        address uniswapV2Router = vm.parseAddress(vm.envString("UNISWAP_V2_ROUTER_MAINNET"));
        address usdcAddress = vm.parseAddress(vm.envString("USDC_MAINNET"));
        uint256 bankCapUsd = vm.envUint("BANK_CAP_USD");
        uint256 withdrawalUsd = vm.envUint("WITHDRAWAL_LIMIT_USD");

        // Sanity checks ON-CHAIN
        require(uniswapV2Router.code.length > 0, "Router: no code at addr");
        require(usdcAddress.code.length > 0, "USDC: no code at addr");

        // Display configuration
        address factory = IRouter(uniswapV2Router).factory();
        address weth = IRouter(uniswapV2Router).WETH();
        console2.log("Router:", uniswapV2Router);
        console2.log("Factory:", factory);
        console2.log("WETH:", weth);
        console2.log("USDC:", usdcAddress);
        console2.log("BANK_CAP_USD:", bankCapUsd);
        console2.log("WITHDRAWAL_LIMIT_USD:", withdrawalUsd);

        // Deploy
        console2.log("Deploying KipuBank...");
        vm.startBroadcast();
        kipuBank = new KipuBank(withdrawalUsd, bankCapUsd, usdcAddress, uniswapV2Router);
        vm.stopBroadcast();
        console2.log("KipuBank deployed at:", address(kipuBank));
    }
}
