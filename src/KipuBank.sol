// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";

/**
 * @author Martín Pielvitori
 * @title KipuBank
 * @dev A multi-token bank contract that accepts ETH and ERC20 tokens with direct USDC pairs.
 *      All deposits are automatically converted to USDC for unified storage. Withdrawals are always in USDC.
 * @notice Supported tokens: ETH, WETH, USDC, and ERC20 tokens with direct Uniswap V2 USDC pairs.
 *         Features role-based access control, pausable operations, and gas-optimized pair validation.
 */
contract KipuBank is ReentrancyGuard, AccessControl, Pausable {
    // Apply SafeERC20 functions to all IERC20 instances
    using SafeERC20 for IERC20;

    /* ===========================================
     *                  Constants
     * =========================================== */

    /// @notice Version of the KipuBank contract
    string public constant VERSION = "3.3.0";

    /// @notice Role for administrators who can manage the bank
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for operators who can perform restricted operations
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice Standard number of decimals for internal USD accounting (6 decimals like USDC)
    uint8 public constant USD_DECIMALS = 6;

    /* ===========================================
     *               State variables
     * =========================================== */

    /// @notice USDC token contract address (immutable for security)
    IERC20 private immutable USDC_TOKEN;

    /// @notice Uniswap V2 Router for token swaps
    IUniswapV2Router02 private uniswapRouter;

    /// @notice Total number of deposit operations performed
    uint256 private depositsCount;

    /// @notice Total number of withdrawal operations performed
    uint256 private withdrawalsCount;

    /// @notice Maximum amount that can be withdrawn in a single transaction (in USD with 6 decimals)
    uint256 private withdrawalLimitUsd;

    /// @notice Total limit of value that can be deposited in the bank (in USD with 6 decimals)
    uint256 private bankCapUsd;

    /// @notice Mapping of user addresses to token addresses to their balances (in USD with 6 decimals)
    /// @dev All balances are stored as USDC amounts after conversion. The mapping is kept bidimensional
    ///      for future extensibility, but currently only USDC address will have non-zero values
    mapping(address => mapping(address => uint256)) public balances;

    /// @notice Mapping to track total deposits per token (in USD with 6 decimals)
    /// @dev All deposits are converted to USDC, so only USDC address will have non-zero values
    ///      Extension-friendly structure for future multi-token support
    mapping(address => uint256) public totalTokenDeposits;

    /* ===========================================
     *                  Events
     * =========================================== */
    /// @notice Emitted when a user makes a deposit
    /// @param account Address of the user making the deposit
    /// @param token Address of the original token deposited (address(0) for ETH only in events, token address for ERC20)
    /// @param tokenSymbol Symbol of the original token deposited ("ETH" for native ETH, token symbol for ERC20)
    /// @param originalAmount Original amount deposited in the token's native decimals
    /// @param usdValue USDC amount received after swap (with 6 decimals), stored under USDC address in balances mapping
    event Deposit(
        address indexed account, address indexed token, string tokenSymbol, uint256 originalAmount, uint256 usdValue
    );

    /// @notice Emitted when a user makes a withdrawal
    /// @param account Address of the user making the withdrawal
    /// @param token Address of the USDC token (withdrawals are always in USDC)
    /// @param tokenSymbol Always "USDC" since all withdrawals are in USDC
    /// @param originalAmount USDC amount withdrawn (with 6 decimals)
    /// @param usdValue Same as originalAmount (USDC amount with 6 decimals)
    event Withdraw(
        address indexed account, address indexed token, string tokenSymbol, uint256 originalAmount, uint256 usdValue
    );

    /// @notice Emitted when the Uniswap V2 Router address is updated by operator
    event UniswapRouterUpdated(address indexed operator, address oldRouter, address newRouter);

    /// @notice Emitted when the withdrawal limit is updated by operator
    event WithdrawalLimitUpdated(address indexed operator, uint256 oldLimit, uint256 newLimit);

    /// @notice Emitted when the bank capacity is updated by operator
    event BankCapUpdated(address indexed operator, uint256 oldCap, uint256 newCap);

    /// @notice Emitted when a role is granted to a user
    event RoleGrantedByAdmin(address indexed admin, address indexed account, bytes32 indexed role);

    /* ===========================================
     *                  Errors
     * =========================================== */
    /// @notice Error thrown when a deposit exceeds the bank's USD capacity
    /// @param attemptedUsd USD value attempted to deposit
    /// @param availableUsd Available USD capacity in the bank
    error ExceedsBankCapUSD(uint256 attemptedUsd, uint256 availableUsd);

    /// @notice Error thrown when a withdrawal exceeds the per-transaction limit
    /// @param attemptedUsd USD value attempted to withdraw
    /// @param limitUsd Maximum withdrawal limit in USD
    error ExceedsWithdrawLimitUSD(uint256 attemptedUsd, uint256 limitUsd);

    /// @notice Error thrown when a user tries to withdraw more than their balance
    /// @param availableUsd User's available balance in USD
    /// @param requiredUsd Amount requested for withdrawal in USD
    error InsufficientBalanceUSD(uint256 availableUsd, uint256 requiredUsd);

    /// @notice Error thrown when an ETH transfer fails
    error TransferFailed();

    /// @notice Error thrown when the withdrawal limit in constructor is invalid
    error InvalidWithdrawLimit();

    /// @notice Error thrown when the bank capacity in constructor is invalid
    error InvalidBankCap();

    /// @notice Error thrown when the provided contract address is invalid
    error InvalidContract();

    /// @notice Error thrown when trying to deposit 0 amount
    error ZeroAmount();

    /// @notice Error thrown when user tries to deposit WETH via depositTokenAsUSD instead of using deposit()
    error UseDepositForETH();

    /// @notice Error thrown when no direct Uniswap V2 pair exists between token and USDC
    error NoDirectPairExists();

    /**
     * @dev Constructor that sets the limits and configures access control.
     * @param _withdrawalLimitUsd Withdrawal limit per transaction in USD (with 6 decimals).
     * @param _bankCapUsd Global deposit limit in USD (with 6 decimals).
     * @param _usdcToken Address of the USDC token contract.
     * @param _uniswapRouter Address of the Uniswap V2 Router contract.
     */
    constructor(uint256 _withdrawalLimitUsd, uint256 _bankCapUsd, address _usdcToken, address _uniswapRouter) {
        if (_withdrawalLimitUsd == 0) {
            revert InvalidWithdrawLimit();
        }
        if (_bankCapUsd == 0) {
            revert InvalidBankCap();
        }
        if (_usdcToken == address(0)) {
            revert InvalidContract();
        }
        if (_uniswapRouter == address(0)) {
            revert InvalidContract();
        }

        withdrawalLimitUsd = _withdrawalLimitUsd;
        bankCapUsd = _bankCapUsd;
        USDC_TOKEN = IERC20(_usdcToken);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);

        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /**
     * @dev Allows users to deposit native ETH, which is automatically swapped to USDC via Uniswap V2.
     * @notice The ETH is converted to USDC at current market rates and stored in the user's balance.
     *         Requires that the deposit does not exceed the global bank USD limit and bank is not paused.
     *         Use this function for native ETH only. For other ERC20 tokens, use depositTokenAsUSD().
     */
    function deposit() external payable nonReentrant whenNotPaused {
        if (msg.value == 0) {
            revert ZeroAmount();
        }

        // Use _depositTokenAsUsd with WETH address to reuse existing logic
        uint256 usdcAmount = _depositTokenAsUsd(msg.sender, msg.value, uniswapRouter.WETH());

        // Emit event with ETH information (not WETH)
        emit Deposit(msg.sender, address(0), "ETH", msg.value, usdcAmount);
    }

    /**
     * @dev Allows users to deposit any ERC20 token with a direct USDC pair on Uniswap V2.
     * @notice The token is automatically swapped to USDC (if not already USDC) and stored in user's balance.
     *         Requires prior token approval and that the bank is not paused.
     *         WETH deposits are rejected - use deposit() for native ETH instead.
     *         Verifies direct pair existence before swap to prevent gas waste on invalid tokens.
     * @param amountIn Amount of token to deposit (in token's native decimals)
     * @param tokenIn Address of the ERC20 token to deposit (must have direct USDC pair on Uniswap V2)
     */
    function depositTokenAsUSD(uint256 amountIn, address tokenIn) external nonReentrant whenNotPaused {
        if (amountIn == 0) {
            revert ZeroAmount();
        }

        // Prevent WETH deposits via this function - users should use deposit() for ETH
        if (tokenIn == uniswapRouter.WETH()) {
            revert UseDepositForETH();
        }

        // Transfer token from user to contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Call internal function to handle the deposit logic
        uint256 usdcAmount = _depositTokenAsUsd(msg.sender, amountIn, tokenIn);

        // Emit event with token symbol
        emit Deposit(msg.sender, tokenIn, IERC20Metadata(tokenIn).symbol(), amountIn, usdcAmount);
    }

    /**
     * @dev Internal function to handle token deposit and swap logic.
     * @notice Converts any token to USDC via Uniswap V2 swap (except USDC which is stored directly).
     *         For ETH deposits, the amount is treated as wei and swapped via swapExactETHForTokens.
     *         For ERC20 deposits, tokens are swapped via swapExactTokensForTokens.
     *         Uses getAmountsOut for pre-validation to check pair existence and bank cap before swap.
     * @param account Address of the account making the deposit
     * @param amount Amount of token to deposit (wei for ETH, token decimals for ERC20)
     * @param tokenAddress Address of the token to deposit (WETH address for ETH deposits)
     * @return usdcAmount Amount of USDC obtained after swap (or original amount if tokenAddress is USDC)
     */
    function _depositTokenAsUsd(address account, uint256 amount, address tokenAddress) private returns (uint256) {
        uint256 usdcAmount;
        if (tokenAddress == address(USDC_TOKEN)) {
            usdcAmount = amount;
            // Check bank capacity for USDC deposits
            uint256 currentTotalUsd = _getTotalBankValueUsd();
            if (currentTotalUsd + usdcAmount > bankCapUsd) {
                revert ExceedsBankCapUSD(usdcAmount, bankCapUsd - currentTotalUsd);
            }
        } else {
            // Get estimated USDC amount and validate pair existence in one call
            uint256 estimatedUsdcAmount = _getExpectedUsdcAmount(amount, tokenAddress);
            // Check bank capacity BEFORE performing the actual swap (fail-fast)
            uint256 currentTotalUsd = _getTotalBankValueUsd();
            if (currentTotalUsd + estimatedUsdcAmount > bankCapUsd) {
                revert ExceedsBankCapUSD(estimatedUsdcAmount, bankCapUsd - currentTotalUsd);
            }
            // Perform actual swap
            usdcAmount = _swapTokenForUsdc(amount, tokenAddress);
        }

        // Effects - USDC already has 6 decimals, store directly
        balances[account][address(USDC_TOKEN)] += usdcAmount;
        totalTokenDeposits[address(USDC_TOKEN)] += usdcAmount;
        ++depositsCount;

        return usdcAmount;
    }

    /**
     * @dev Allows users to withdraw USDC from their personal vault.
     * @notice All withdrawals are in USDC regardless of the original deposit token.
     *         Users receive actual USDC tokens transferred to their address.
     * @param amount Amount of USDC to withdraw (with 6 decimals)
     */
    function withdrawUSD(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) {
            revert ZeroAmount();
        }

        // Checks - use limit
        if (amount > withdrawalLimitUsd) {
            revert ExceedsWithdrawLimitUSD(amount, withdrawalLimitUsd);
        }

        uint256 userBalanceUsd = balances[msg.sender][address(USDC_TOKEN)];
        if (userBalanceUsd < amount) {
            revert InsufficientBalanceUSD(userBalanceUsd, amount);
        }

        // Effects
        balances[msg.sender][address(USDC_TOKEN)] -= amount;
        totalTokenDeposits[address(USDC_TOKEN)] -= amount;
        ++withdrawalsCount;
        emit Withdraw(msg.sender, address(USDC_TOKEN), "USDC", amount, amount);

        // Interactions - safe ERC20 transfer
        USDC_TOKEN.safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Swaps a given token for USDC using Uniswap V2 with direct pairs only.
     * @notice For WETH (ETH deposits): Uses swapExactETHForTokens with msg.value
     *         For ERC20 tokens: Uses swapExactTokensForTokens with 2-element path [tokenIn, USDC]
     *         No multi-hop routing - requires direct USDC pairs on Uniswap V2
     * @param amountIn Amount of the input token to swap (wei for ETH, token decimals for ERC20)
     * @param tokenIn Address of the input token (WETH address for ETH, ERC20 address for tokens)
     * @return Amount of USDC received from the swap (6 decimals)
     */
    function _swapTokenForUsdc(uint256 amountIn, address tokenIn) private returns (uint256) {
        // Handle WETH case specially for ETH deposits
        if (tokenIn == uniswapRouter.WETH()) {
            address[] memory path = new address[](2);
            path[0] = uniswapRouter.WETH();
            path[1] = address(USDC_TOKEN);

            // Swap ETH -> USDC
            uint256[] memory amounts =
                uniswapRouter.swapExactETHForTokens{value: amountIn}(0, path, address(this), block.timestamp);

            return amounts[amounts.length - 1];
        } else {
            // Handle regular ERC20 token case
            // ensure allowance for router
            if (IERC20(tokenIn).allowance(address(this), address(uniswapRouter)) < amountIn) {
                // Approve Uniswap Router to spend tokenIn
                IERC20(tokenIn).safeIncreaseAllowance(address(uniswapRouter), amountIn);
            }

            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = address(USDC_TOKEN);

            // Direct swap tokenIn -> USDC
            uint256[] memory amounts =
                uniswapRouter.swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);

            return amounts[amounts.length - 1];
        }
    }

    /**
     * @dev Gets estimated USDC amount for a given token amount using getAmountsOut.
     * @notice This function serves dual purpose: validates pair existence AND estimates output.
     *         If no direct pair exists, getAmountsOut will revert with "UniswapV2Library: INSUFFICIENT_LIQUIDITY".
     *         Replaces separate _hasDirectPairWithUSDC() call for gas efficiency.
     * @param amountIn Amount of input token
     * @param tokenIn Address of input token (WETH for ETH deposits, ERC20 address for tokens)
     * @return estimatedUsdcAmount Estimated USDC amount that would be received
     */
    function _getExpectedUsdcAmount(uint256 amountIn, address tokenIn) private view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = address(USDC_TOKEN);

        try uniswapRouter.getAmountsOut(amountIn, path) returns (uint256[] memory amounts) {
            return amounts[amounts.length - 1];
        } catch {
            // getAmountsOut reverts if no pair exists or insufficient liquidity
            revert NoDirectPairExists();
        }
    }

    /**
     * @dev Gets the total bank value in USD (6 decimals).
     * @return Total USD value of all deposits.
     */
    function _getTotalBankValueUsd() private view returns (uint256) {
        return totalTokenDeposits[address(USDC_TOKEN)];
    }

    /**
     * @dev Public view function to get the current Uniswap V2 Router address.
     * @return The address of the current Uniswap V2 Router contract.
     * @notice This function can be called by any user without gas cost.
     */
    function getUniswapRouter() external view returns (address) {
        return address(uniswapRouter);
    }

    /**
     * @dev Public view function to get the current USDC token address.
     * @return The address of the USDC token contract.
     * @notice This function can be called by any user without gas cost.
     */
    function getUSDCAddress() external view returns (address) {
        return address(USDC_TOKEN);
    }

    /**
     * @dev Public view function to get the total bank value according to internal accounting.
     * @return The total USD value tracked by internal deposit records (6 decimals).
     * @notice This represents the sum of all user deposits converted to USDC.
     *         Should match getBankUSDCBalance() under normal conditions.
     *         Discrepancies may indicate direct transfers or accounting issues.
     */
    function getBankValueUSD() external view returns (uint256) {
        return _getTotalBankValueUsd();
    }

    /**
     * @dev Public view function to get the USD capacity limit.
     * @return The maximum USD value that can be deposited in the bank (6 decimals).
     * @notice This function can be called by any user without gas cost.
     */
    function getBankCapUSD() external view returns (uint256) {
        return bankCapUsd;
    }

    /**
     * @dev Public view function to get the withdrawal limit in USD.
     * @return The maximum USD value that can be withdrawn per transaction (6 decimals).
     * @notice This function can be called by any user without gas cost.
     */
    function getWithdrawalLimitUSD() external view returns (uint256) {
        return withdrawalLimitUsd;
    }

    /**
     * @dev Public view function to query the total number of deposits made.
     * @return The total number of completed deposit operations.
     * @notice This function can be called by any user without gas cost.
     */
    function getDepositsCount() external view returns (uint256) {
        return depositsCount;
    }

    /**
     * @dev Public view function to query the total number of withdrawals made.
     * @return The total number of completed withdrawal operations.
     * @notice This function can be called by any user without gas cost.
     */
    function getWithdrawalsCount() external view returns (uint256) {
        return withdrawalsCount;
    }

    /**
     * @dev Public view function to query the bank's actual USDC token balance.
     * @return The actual USDC balance held by the contract according to the USDC token.
     * @notice This represents the true USDC tokens owned by this contract.
     *         Should match getBankValueUSD() under normal conditions.
     *         May differ due to direct transfers, swap residue, or fees.
     */
    function getBankUSDCBalance() external view returns (uint256) {
        return USDC_TOKEN.balanceOf(address(this));
    }

    /**
     * @dev Public view function to query a user's balance in USDC.
     * @notice Since all deposits are converted and stored as USDC, this returns the user's
     *         complete balance regardless of what tokens were originally deposited.
     * @param account Address of the user to query
     * @return The user's balance in USDC (6 decimals)
     */
    function getUserBalance(address account) external view returns (uint256) {
        return balances[account][address(USDC_TOKEN)];
    }

    /* ===========================================
     *        Admin functions (ADMIN_ROLE)
     * =========================================== */
    /**
     * @dev Emergency function to pause the bank (deposits only).
     * @notice Only admins can call this function. Withdrawals remain active.
     * @notice Reverts with EnforcedPause() if bank is already paused.
     */
    function pauseBank() external onlyRole(ADMIN_ROLE) whenNotPaused {
        _pause();
    }

    /**
     * @dev Function to unpause the bank.
     * @notice Only admins can call this function.
     * @notice Reverts with ExpectedPause() if bank is already unpaused.
     */
    function unpauseBank() external onlyRole(ADMIN_ROLE) whenPaused {
        _unpause();
    }

    /**
     * @dev Grant OPERATOR_ROLE to a new user.
     * @notice Only admins can call this function.
     * @param account Address to grant operator role to.
     */
    function grantOperatorRole(address account) external onlyRole(ADMIN_ROLE) {
        if (account == address(0)) {
            revert InvalidContract();
        }

        _grantRole(OPERATOR_ROLE, account);
        emit RoleGrantedByAdmin(msg.sender, account, OPERATOR_ROLE);
    }

    /* ===========================================
     *     Operator functions (OPERATOR_ROLE)
     * =========================================== */

    /**
     * @dev Update the Uniswap V2 Router address.
     * @notice Only operators can call this function.
     * @param newRouter New Uniswap V2 Router address.
     */
    function updateUniswapRouter(address newRouter) external onlyRole(OPERATOR_ROLE) {
        if (newRouter == address(0)) {
            revert InvalidContract();
        }

        address oldRouter = address(uniswapRouter);
        uniswapRouter = IUniswapV2Router02(newRouter);

        emit UniswapRouterUpdated(msg.sender, oldRouter, newRouter);
    }

    /**
     * @dev Update the withdrawal limit in USD.
     * @notice Only operators can call this function.
     * @param newLimit New withdrawal limit in USD (with 6 decimals).
     */
    function updateWithdrawalLimit(uint256 newLimit) external onlyRole(OPERATOR_ROLE) {
        if (newLimit == 0) {
            revert InvalidWithdrawLimit();
        }

        uint256 oldLimit = withdrawalLimitUsd;
        withdrawalLimitUsd = newLimit;

        emit WithdrawalLimitUpdated(msg.sender, oldLimit, newLimit);
    }

    /**
     * @dev Update the bank capacity in USD.
     * @notice Only operators can call this function.
     * @param newCap New bank capacity in USD (with 6 decimals).
     */
    function updateBankCap(uint256 newCap) external onlyRole(OPERATOR_ROLE) {
        if (newCap == 0) {
            revert InvalidBankCap();
        }

        uint256 oldCap = bankCapUsd;
        bankCapUsd = newCap;

        emit BankCapUpdated(msg.sender, oldCap, newCap);
    }
}
