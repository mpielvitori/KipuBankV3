// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console2} from "forge-std/Script.sol";
import {KipuBank} from "../src/KipuBank.sol";

/**
 * @title User Helper Script
 * @notice Unified utility script for KipuBank user analysis and balance conversion
 * @dev Run with: forge script script/UserHelper.s.sol --rpc-url $RPC_URL -vvv
 */
contract UserHelper is Script {
    /**
     * @notice Main function to demonstrate all functionalities
     */
    function run() external view {
        address kipuBankAddress = vm.envOr("KIPUBANK_ADDRESS", address(0));
        require(kipuBankAddress != address(0), "Set KIPUBANK_ADDRESS env variable");

        KipuBank kipuBank = KipuBank(kipuBankAddress);

        console2.log("=== KipuBank User Helper ===");
        console2.log("KipuBank Address:", kipuBankAddress);

        // Bank state and statistics
        bankStats();
        checkBankState(kipuBank);
    }

    /**
     * @notice Check user balance and display in readable format
     * @param user User address to check
     */
    function checkUser(address user) external view {
        address kipuBankAddress = vm.envOr("KIPUBANK_ADDRESS", address(0));
        require(kipuBankAddress != address(0), "Set KIPUBANK_ADDRESS env variable");
        KipuBank kipuBank = KipuBank(kipuBankAddress);

        console2.log("======= User Analysis =======");
        console2.log("User Address:", user);

        uint256 balance = kipuBank.getUserBalance(user);
        console2.log("Raw Balance (wei):", balance);
        console2.log("Balance USD:", balance / 1e6);

        // Additional user context
        uint256 withdrawalLimit = kipuBank.getWithdrawalLimitUSD();
        console2.log("Withdrawal Limit USD:", withdrawalLimit / 1e6);

        if (balance > withdrawalLimit) {
            console2.log("STATUS: User can withdraw up to limit");
        } else if (balance > 0) {
            console2.log("STATUS: User balance below withdrawal limit");
        } else {
            console2.log("STATUS: User has no balance");
        }
    }

    /**
     * @notice Display comprehensive bank statistics
     */
    function bankStats() public view {
        address kipuBankAddress = vm.envOr("KIPUBANK_ADDRESS", address(0));
        require(kipuBankAddress != address(0), "Set KIPUBANK_ADDRESS env variable");
        KipuBank kipuBank = KipuBank(kipuBankAddress);

        console2.log("======= Bank Statistics =======");
        console2.log("Bank Value USD:", kipuBank.getBankValueUSD() / 1e6);
        console2.log("USDC Balance:", kipuBank.getBankUSDCBalance() / 1e6);
        console2.log("Bank Cap USD:", kipuBank.getBankCapUSD() / 1e6);
        console2.log("Withdrawal Limit USD:", kipuBank.getWithdrawalLimitUSD() / 1e6);
        console2.log("Withdrawal Count:", kipuBank.getWithdrawalsCount());
        console2.log("Deposit Count:", kipuBank.getDepositsCount());

        // Capacity analysis
        uint256 bankValue = kipuBank.getBankValueUSD();
        uint256 bankCap = kipuBank.getBankCapUSD();
        uint256 availableCapacity = bankCap > bankValue ? bankCap - bankValue : 0;
        console2.log("Available Capacity USD:", availableCapacity / 1e6);

        // Utilization percentage
        uint256 utilization = bankCap > 0 ? (bankValue * 100) / bankCap : 0;
        console2.log("Bank Utilization %:", utilization);
    }

    /**
     * @notice Convert raw balance to human-readable USDC
     * @param rawBalance Raw balance in USDC wei (6 decimals)
     */
    function convertBalanceToUsdc(uint256 rawBalance) public pure {
        console2.log("======= Balance Conversion =======");
        console2.log("Raw balance (wei):", rawBalance);

        uint256 dollars = rawBalance / 1e6;
        uint256 cents = (rawBalance % 1e6) / 1e4; // Get 2 decimal places

        console2.log("Converted balance USD:", dollars);
        if (cents > 0) {
            console2.log("Cents:", cents);
        }
    }

    /**
     * @notice Check general bank state and health
     * @param kipuBank KipuBank contract instance
     */
    function checkBankState(KipuBank kipuBank) public view {
        console2.log("======= Bank Health Check =======");

        uint256 bankValueUSD = kipuBank.getBankValueUSD();
        uint256 bankUSDCBalance = kipuBank.getBankUSDCBalance();
        uint256 bankCap = kipuBank.getBankCapUSD();

        console2.log("Bank Value USD:", bankValueUSD / 1e6);
        console2.log("Bank USDC Balance:", bankUSDCBalance / 1e6);
        console2.log("Bank Cap USD:", bankCap / 1e6);

        // Health checks
        if (bankValueUSD == bankUSDCBalance) {
            console2.log("SUCCESS: Internal accounting matches USDC balance");
        } else {
            console2.log("WARNING: Accounting mismatch detected!");
            uint256 diff =
                bankValueUSD > bankUSDCBalance ? (bankValueUSD - bankUSDCBalance) : (bankUSDCBalance - bankValueUSD);
            console2.log("Difference USD:", diff / 1e6);
        }

        // Capacity check
        if (bankValueUSD >= bankCap) {
            console2.log("WARNING: Bank at or above capacity!");
        } else {
            uint256 remaining = bankCap - bankValueUSD;
            console2.log("Remaining capacity USD:", remaining / 1e6);
        }

        // Additional checks if available
        try kipuBank.paused() returns (bool isPaused) {
            console2.log("Bank Status:", isPaused ? "PAUSED" : "ACTIVE");
        } catch {
            console2.log("Could not check pause status");
        }
    }

    /**
     * @notice Check user balance for specific address (standalone function for external calls)
     * @param user User address to check
     */
    function checkUserBalance(address user) external view {
        address kipuBankAddress = vm.envOr("KIPUBANK_ADDRESS", address(0));
        require(kipuBankAddress != address(0), "Set KIPUBANK_ADDRESS env variable");

        KipuBank kipuBank = KipuBank(kipuBankAddress);

        console2.log("======= User Balance Check =======");
        console2.log("User Address:", user);

        uint256 balance = kipuBank.getUserBalance(user);
        convertBalanceToUsdc(balance);
    }
}
