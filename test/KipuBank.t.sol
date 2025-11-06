// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {KipuBank} from "../src/KipuBank.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KipuBankTest is Test {
    KipuBank public kipuBank;

    // Test parameters
    uint256 constant WITHDRAWAL_LIMIT = 1000 * 10 ** 6; // 1,000 USDC
    uint256 constant BANK_CAP = 5000 * 10 ** 6; // 5,000 USDC

    // Contract addresses - use environment variables with fallbacks
    address public usdcAddress;
    address public uniswapRouter;
    address public wethAddress;

    // Whale addresses (accounts with large token balances)
    address constant USDC_WHALE = 0x28C6c06298d514Db089934071355E5743bf21d60; // Binance 14 - large USDC holder
    address constant ETH_WHALE = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;

    // Test accounts
    address public admin;
    address public operator;
    address public user1;
    address public user2;

    // Events to test
    event Deposit(
        address indexed account, address indexed token, string tokenSymbol, uint256 originalAmount, uint256 usdValue
    );
    event Withdraw(
        address indexed account, address indexed token, string tokenSymbol, uint256 originalAmount, uint256 usdValue
    );

    function setUp() public {
        // Get addresses from environment variables with reasonable defaults
        usdcAddress = vm.envOr("USDC_MAINNET", address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
        uniswapRouter = vm.envOr("UNISWAP_V2_ROUTER_MAINNET", address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
        wethAddress = vm.envOr("WETH_MAINNET", address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        uint256 blockNumber = vm.envOr("FORK_BLOCK_NUMBER", uint256(23736580));
        string memory rpcUrl = vm.envString("FOUNDRY_ETH_RPC_URL");
        console.log("Forking from RPC:", rpcUrl);
        vm.createFork(rpcUrl, blockNumber);

        // Set up test accounts
        admin = address(this);
        operator = makeAddr("operator");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy KipuBank contract
        kipuBank = new KipuBank(WITHDRAWAL_LIMIT, BANK_CAP, usdcAddress, uniswapRouter);

        // Grant operator role
        kipuBank.grantOperatorRole(operator);

        // Fund test accounts with ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    // ===== HELPER FUNCTIONS =====

    function _fundUserWithUSDC(address user, uint256 amount) internal {
        // Only work if we have a fork with real contracts
        if (block.number > 1 && usdcAddress != address(0)) {
            IERC20 usdc = IERC20(usdcAddress);

            // Check whale balance first
            uint256 whaleBalance = usdc.balanceOf(USDC_WHALE);

            if (whaleBalance >= amount) {
                // Transfer from whale to user
                vm.prank(USDC_WHALE);
                usdc.transfer(user, amount);
            }
        }
    }

    // ===== CONSTRUCTOR TESTS =====

    function testConstructorWithValidParameters() public view {
        assertEq(kipuBank.getWithdrawalLimitUSD(), WITHDRAWAL_LIMIT);
        assertEq(kipuBank.getBankCapUSD(), BANK_CAP);
        assertEq(kipuBank.getUSDCAddress(), usdcAddress);
        assertEq(kipuBank.getUniswapRouter(), uniswapRouter);
        assertEq(kipuBank.VERSION(), "3.0.0");
        assertTrue(kipuBank.hasRole(kipuBank.ADMIN_ROLE(), admin));
        assertTrue(kipuBank.hasRole(kipuBank.OPERATOR_ROLE(), admin));
    }

    function testConstructorWithInvalidWithdrawalLimit() public {
        vm.expectRevert(KipuBank.InvalidWithdrawLimit.selector);
        new KipuBank(0, BANK_CAP, usdcAddress, uniswapRouter);
    }

    function testConstructorWithInvalidBankCap() public {
        vm.expectRevert(KipuBank.InvalidBankCap.selector);
        new KipuBank(WITHDRAWAL_LIMIT, 0, usdcAddress, uniswapRouter);
    }

    function testConstructorWithInvalidUSDCAddress() public {
        vm.expectRevert(KipuBank.InvalidContract.selector);
        new KipuBank(WITHDRAWAL_LIMIT, BANK_CAP, address(0), uniswapRouter);
    }

    function testConstructorWithInvalidRouterAddress() public {
        vm.expectRevert(KipuBank.InvalidContract.selector);
        new KipuBank(WITHDRAWAL_LIMIT, BANK_CAP, usdcAddress, address(0));
    }

    // ===== DEPOSIT TESTS =====

    function testETHDepositZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(KipuBank.ZeroAmount.selector);
        kipuBank.deposit{value: 0}();
        vm.stopPrank();
    }

    function testDepositWhenPaused() public {
        // Pause the bank
        kipuBank.pauseBank();

        vm.startPrank(user1);
        vm.expectRevert(); // Should revert with EnforcedPause
        kipuBank.deposit{value: 1 ether}();
        vm.stopPrank();
    }

    function testETHDepositSuccess() public {
        uint256 depositAmount = 0.1 ether;

        vm.startPrank(user1);

        uint256 bankValueBefore = kipuBank.getBankValueUSD();
        uint256 bankBalanceBefore = kipuBank.getBankUSDCBalance();
        uint256 userBalanceBefore = kipuBank.getUserBalance(user1);

        // Expect Deposit event to be emitted
        vm.expectEmit(true, true, false, false);
        emit Deposit(user1, address(0), "ETH", depositAmount, 0); // usdValue will vary

        kipuBank.deposit{value: depositAmount}();

        uint256 bankValueAfter = kipuBank.getBankValueUSD();
        uint256 bankBalanceAfter = kipuBank.getBankUSDCBalance();
        uint256 userBalanceAfter = kipuBank.getUserBalance(user1);

        assertGt(bankValueAfter, bankValueBefore, "Bank value should increase");
        assertGt(bankBalanceAfter, bankBalanceBefore, "Bank USDC balance should increase");
        assertGt(userBalanceAfter, userBalanceBefore, "User balance should increase");
        assertEq(bankValueAfter, bankBalanceAfter, "Bank value and USDC balance should match");
        assertEq(kipuBank.getDepositsCount(), 1, "Deposits count should be 1");

        vm.stopPrank();
    }

    // ===== ERC20 DEPOSIT TESTS =====

    function testERC20DepositZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(KipuBank.ZeroAmount.selector);
        kipuBank.depositTokenAsUSD(0, usdcAddress);
        vm.stopPrank();
    }

    function testWETHDepositRejection() public {
        if (wethAddress != address(0)) {
            vm.startPrank(user1);
            vm.expectRevert(KipuBank.UseDepositForETH.selector);
            kipuBank.depositTokenAsUSD(1 ether, wethAddress);
            vm.stopPrank();
        }
    }

    // ===== WITHDRAWAL TESTS =====

    function testWithdrawZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(KipuBank.ZeroAmount.selector);
        kipuBank.withdrawUSD(0);
        vm.stopPrank();
    }

    function testWithdrawExceedsLimit() public {
        vm.startPrank(user1);
        uint256 excessiveAmount = WITHDRAWAL_LIMIT + 1;
        vm.expectRevert(
            abi.encodeWithSelector(KipuBank.ExceedsWithdrawLimitUSD.selector, excessiveAmount, WITHDRAWAL_LIMIT)
        );
        kipuBank.withdrawUSD(excessiveAmount);
        vm.stopPrank();
    }

    function testWithdrawInsufficientBalance() public {
        uint256 withdrawAmount = 100 * 10 ** 6; // 100 USDC

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(KipuBank.InsufficientBalanceUSD.selector, 0, withdrawAmount));
        kipuBank.withdrawUSD(withdrawAmount);
        vm.stopPrank();
    }

    // ===== ACCESS CONTROL TESTS =====

    function testPauseBankOnlyAdmin() public {
        vm.startPrank(user1);
        vm.expectRevert(); // Should revert with AccessControl error
        kipuBank.pauseBank();
        vm.stopPrank();
    }

    function testUnpauseBankOnlyAdmin() public {
        kipuBank.pauseBank(); // Pause first

        vm.startPrank(user1);
        vm.expectRevert(); // Should revert with AccessControl error
        kipuBank.unpauseBank();
        vm.stopPrank();
    }

    function testPauseUnpauseFlow() public {
        assertFalse(kipuBank.paused(), "Should start unpaused");

        kipuBank.pauseBank();
        assertTrue(kipuBank.paused(), "Should be paused");

        kipuBank.unpauseBank();
        assertFalse(kipuBank.paused(), "Should be unpaused");
    }

    function testPauseWhenAlreadyPaused() public {
        kipuBank.pauseBank();

        vm.expectRevert(); // Should revert with EnforcedPause
        kipuBank.pauseBank();
    }

    function testUnpauseWhenNotPaused() public {
        vm.expectRevert(); // Should revert with ExpectedPause
        kipuBank.unpauseBank();
    }

    function testGrantOperatorRole() public {
        address newOperator = makeAddr("newOperator");

        assertFalse(kipuBank.hasRole(kipuBank.OPERATOR_ROLE(), newOperator));

        kipuBank.grantOperatorRole(newOperator);

        assertTrue(kipuBank.hasRole(kipuBank.OPERATOR_ROLE(), newOperator));
    }

    function testGrantOperatorRoleOnlyAdmin() public {
        address newOperator = makeAddr("newOperator");

        vm.startPrank(user1);
        vm.expectRevert(); // Should revert with AccessControl error
        kipuBank.grantOperatorRole(newOperator);
        vm.stopPrank();
    }

    function testGrantOperatorRoleToZeroAddress() public {
        vm.expectRevert(KipuBank.InvalidContract.selector);
        kipuBank.grantOperatorRole(address(0));
    }

    // ===== OPERATOR FUNCTIONS TESTS =====

    function testUpdateUniswapRouter() public {
        address newRouter = makeAddr("newRouter");

        vm.startPrank(operator);
        kipuBank.updateUniswapRouter(newRouter);
        vm.stopPrank();

        assertEq(kipuBank.getUniswapRouter(), newRouter);
    }

    function testUpdateUniswapRouterOnlyOperator() public {
        address newRouter = makeAddr("newRouter");

        vm.startPrank(user1);
        vm.expectRevert(); // Should revert with AccessControl error
        kipuBank.updateUniswapRouter(newRouter);
        vm.stopPrank();
    }

    function testUpdateUniswapRouterZeroAddress() public {
        vm.startPrank(operator);
        vm.expectRevert(KipuBank.InvalidContract.selector);
        kipuBank.updateUniswapRouter(address(0));
        vm.stopPrank();
    }

    // ===== VIEW FUNCTIONS TESTS =====

    function testViewFunctions() public view {
        assertEq(kipuBank.getBankValueUSD(), 0);
        assertEq(kipuBank.getBankUSDCBalance(), 0);
        assertEq(kipuBank.getDepositsCount(), 0);
        assertEq(kipuBank.getWithdrawalsCount(), 0);
        assertEq(kipuBank.getUserBalance(user1), 0);
    }

    function testBankValueVsBankBalance() public view {
        // Both functions should return the same value under normal conditions
        uint256 bankValue = kipuBank.getBankValueUSD();
        uint256 bankBalance = kipuBank.getBankUSDCBalance();

        assertEq(bankValue, bankBalance, "Bank value and USDC balance should match");
    }

    // ===== INTEGRATION TESTS =====

    function testFullDepositWithdrawCycle() public {
        // Test USDC deposit (direct deposit, no swap needed)
        uint256 depositAmount = 1000 * 10 ** 6; // 1000 USDC
        _fundUserWithUSDC(user1, depositAmount);

        vm.startPrank(user1);
        IERC20(usdcAddress).approve(address(kipuBank), depositAmount);

        uint256 balanceBefore = kipuBank.getUserBalance(user1);
        kipuBank.depositTokenAsUSD(depositAmount, usdcAddress);
        uint256 balanceAfter = kipuBank.getUserBalance(user1);

        assertEq(balanceAfter - balanceBefore, depositAmount, "USDC deposit failed");

        // Test withdrawal
        uint256 withdrawAmount = 500 * 10 ** 6; // 500 USDC
        uint256 usdcBalanceBefore = IERC20(usdcAddress).balanceOf(user1);

        kipuBank.withdrawUSD(withdrawAmount);

        uint256 usdcBalanceAfter = IERC20(usdcAddress).balanceOf(user1);
        uint256 bankBalanceAfter = kipuBank.getUserBalance(user1);

        assertEq(usdcBalanceAfter - usdcBalanceBefore, withdrawAmount, "USDC withdrawal failed");
        assertEq(bankBalanceAfter, depositAmount - withdrawAmount, "Bank balance incorrect after withdrawal");

        vm.stopPrank();
    }

    function testMultipleUsersDeposits() public {
        uint256 depositAmount1 = 1000 * 10 ** 6; // 1000 USDC
        uint256 depositAmount2 = 2000 * 10 ** 6; // 2000 USDC

        // Fund both users with USDC
        _fundUserWithUSDC(user1, depositAmount1);
        _fundUserWithUSDC(user2, depositAmount2);

        // User1 deposits
        vm.startPrank(user1);
        IERC20(usdcAddress).approve(address(kipuBank), depositAmount1);
        kipuBank.depositTokenAsUSD(depositAmount1, usdcAddress);
        vm.stopPrank();

        // User2 deposits
        vm.startPrank(user2);
        IERC20(usdcAddress).approve(address(kipuBank), depositAmount2);
        kipuBank.depositTokenAsUSD(depositAmount2, usdcAddress);
        vm.stopPrank();

        // Verify independent balances
        assertEq(kipuBank.getUserBalance(user1), depositAmount1, "User1 balance incorrect");
        assertEq(kipuBank.getUserBalance(user2), depositAmount2, "User2 balance incorrect");
        assertEq(kipuBank.getBankValueUSD(), depositAmount1 + depositAmount2, "Total bank value incorrect");
    }

    // ===== EDGE CASES =====

    function testBankCapEnforcement() public {
        // Try to deposit an amount that would exceed the bank cap (5000 USDC)
        uint256 largeAmount = 6000 * 10 ** 6; // 6000 USDC (exceeds 5000 cap)

        if (usdcAddress != address(0)) {
            // Fund user1 with enough USDC for the test
            _fundUserWithUSDC(user1, largeAmount);

            vm.startPrank(user1);
            IERC20(usdcAddress).approve(address(kipuBank), largeAmount);

            vm.expectRevert(abi.encodeWithSelector(KipuBank.ExceedsBankCapUSD.selector, largeAmount, BANK_CAP));
            kipuBank.depositTokenAsUSD(largeAmount, usdcAddress);
            vm.stopPrank();
        }
    }

    function testWithdrawalLimitEnforcement() public {
        if (usdcAddress != address(0)) {
            // First deposit some USDC
            uint256 depositAmount = 2000 * 10 ** 6; // 2000 USDC
            _fundUserWithUSDC(user1, depositAmount);

            vm.startPrank(user1);
            IERC20(usdcAddress).approve(address(kipuBank), depositAmount);
            kipuBank.depositTokenAsUSD(depositAmount, usdcAddress);

            // Try to withdraw more than the limit (1000 USDC)
            uint256 largeWithdrawal = 1500 * 10 ** 6; // 1500 USDC (exceeds 1000 limit)
            vm.expectRevert(
                abi.encodeWithSelector(KipuBank.ExceedsWithdrawLimitUSD.selector, largeWithdrawal, WITHDRAWAL_LIMIT)
            );
            kipuBank.withdrawUSD(largeWithdrawal);
            vm.stopPrank();
        }
    }

    function testInsufficientBalance() public {
        vm.startPrank(user1);

        // Try to withdraw without any deposits
        uint256 withdrawAmount = 100 * 10 ** 6; // 100 USDC
        vm.expectRevert(abi.encodeWithSelector(KipuBank.InsufficientBalanceUSD.selector, 0, withdrawAmount));
        kipuBank.withdrawUSD(withdrawAmount);

        vm.stopPrank();
    }

    // ===== ETH DEPOSIT TESTS =====

    function testETHDeposit() public {
        // Only test if we have a fork with real contracts
        if (block.number > 1) {
            vm.startPrank(user1);
            vm.deal(user1, 1 ether);

            uint256 depositAmount = 0.1 ether;
            uint256 bankValueBefore = kipuBank.getBankValueUSD();
            uint256 userBalanceBefore = kipuBank.getUserBalance(user1);

            kipuBank.deposit{value: depositAmount}();

            uint256 bankValueAfter = kipuBank.getBankValueUSD();
            uint256 userBalanceAfter = kipuBank.getUserBalance(user1);

            // Should have received some USDC from the ETH swap
            assertGt(userBalanceAfter, userBalanceBefore, "User balance should increase after ETH deposit");
            assertGt(bankValueAfter, bankValueBefore, "Bank value should increase after ETH deposit");
            assertEq(kipuBank.getDepositsCount(), 1, "Deposits count should be 1");

            vm.stopPrank();
        }
    }
}
