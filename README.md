## Foundry

### Installation

```shell
forge install OpenZeppelin/openzeppelin-contracts
forge install Uniswap/v2-periphery
forge install foundry-rs/forge-std
```

### Environment Setup

1. Copy `.env.example` to `.env` and configure your settings:
```shell
cp .env.example .env
```

2. Edit `.env` and update the following variables:
   - `ETH_RPC_URL`: Your Ethereum mainnet RPC endpoint (Alchemy, Infura, etc.)
   - `SEPOLIA_RPC_URL`: Your Sepolia testnet RPC endpoint
   - `WALLET_ADDRESS`: Your deployment wallet address
   - `PRIVATE_KEY`: Your private key (for deployment only, never commit!)

3. Load environment variables:
```shell
source .env
```

**Note**: For testing with forks, you need a valid `ETH_RPC_URL`. You can use:
- Alchemy: `https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY`
- Infura: `https://mainnet.infura.io/v3/YOUR_PROJECT_ID`
- Public RPC: `https://eth.public-rpc.com` (slower but free)

Map libraries
```shell
forge remappings > remappings.txt
```

### Build

```shell
forge build
```

### Testing

#### Run Unit Tests (with Mainnet Fork)
```shell
forge test
```

#### Run Specific Test
```shell
forge test --match-test testETHDepositSuccess -vvv
```

#### Run Tests with Gas Report
```shell
forge test --gas-report
```

**Note**: Tests use Ethereum mainnet fork to interact with real Uniswap contracts. Make sure your `ETH_RPC_URL` is configured in `.env`.


# KipuBank - Smart Contract

![Solidity](https://img.shields.io/badge/Solidity-^0.8.22-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## 📋 Description

KipuBank is a smart contract developed in Solidity that simulates a multi-token decentralized bank. It allows users to deposit ETH and any ERC20 tokens, automatically converting them to USDC for unified storage and accounting.

### Main Features

- **Multi-Token Support**: Accepts ETH and any ERC20 token with direct Uniswap V2 pairs to USDC
- **Uniswap Integration**: Automatic token swaps using Uniswap V2 Router for real-time conversions
- **Unified USDC Storage**: All deposits converted and stored as USDC for simplified accounting
- **Access Control**: Role-based system (Admin/Operator) with OpenZeppelin AccessControl
- **Advanced Security**: Reentrancy protection and comprehensive validations
- **Configurable Limits**: Global capacity and USD withdrawal limits
- **Events and Statistics**: Complete multi-token operation logging

## 🏗️ Contract Architecture

### Key Variables
- `WITHDRAWAL_LIMIT_USD` (immutable): Maximum USD per withdrawal
- `BANK_CAP_USD` (immutable): Total bank capacity in USD
- `balances`: User balances mapping (all stored as USDC amounts)
- `uniswapRouter`: Uniswap V2 Router for token swaps
- `USDC_TOKEN` (immutable): USDC contract address (set at deployment for security)

### Main Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `deposit()` | external payable | Deposit ETH (swapped to USDC via Uniswap) |
| `depositTokenAsUSD(amount, token)` | external | Deposit any ERC20 token (swapped to USDC) |
| `withdrawUSD(amount)` | external | Withdraw USDC directly |
| `getUserBalance(user)` | external view | View user balance in USDC |
| `getBankValueUSD()` | external view | View total USD value per internal accounting |
| `getUniswapRouter()` | external view | View current Uniswap Router address |

### Implemented Security
- ✅ **Reentrancy Protection**: OpenZeppelin ReentrancyGuard
- ✅ **Access Control**: Admin/Operator role-based system
- ✅ **CEI Pattern**: Checks-Effects-Interactions properly implemented
- ✅ **Custom Errors**: Specific error types for each validation
- ✅ **Safe Transfers**: Use of `.call()` for ETH and standard ERC20
- ✅ **Oracle Validation**: Verification of valid price data

## 🚀 Deployment on Remix IDE

### Step 1: Preparation
1. Open [Remix IDE](https://remix.ethereum.org)
2. Connect MetaMask to **Sepolia Testnet**
3. Ensure you have test ETH ([Sepolia Faucet](https://faucet.aragua.org/))

### Step 2: Get Required Addresses
For Sepolia testnet, you'll need:
1. **USDC Token Address**: Use real Sepolia USDC or deploy a test token
2. **Uniswap V2 Router**: `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`

### Step 3: Deploy KipuBank
1. Go to "Solidity Compiler" → Version `0.8.22+`
2. Compile `KipuBank.sol`
3. Configure constructor parameters:

```
_withdrawalLimitUSD: 1000000000     (1,000 USD with 6 decimals)
_bankCapUSD:         5000000000     (5,000 USD with 6 decimals)
_usdcToken:          USDC_TOKEN_ADDRESS
_uniswapRouter:      0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
```

4. Click "Deploy" → Confirm in MetaMask
5. ✅ Contract deployed!

## 🔧 Contract Interaction

### Making ETH Deposits
```javascript
// In Remix:
// 1. Go to "VALUE" → Enter amount in wei
// 2. Click "deposit" button (orange)
// 3. Confirm transaction in MetaMask
// 4. ETH automatically swapped to USDC via Uniswap

Example values:
0.1 ETH = 100000000000000000 wei
0.05 ETH = 50000000000000000 wei
```

### Making ERC20 Token Deposits
```javascript
// For ANY ERC20 token (USDT, DAI, WBTC, etc.):

// 1. First approve token in the token contract:
approve(KIPUBANK_ADDRESS, TOKEN_AMOUNT)

// 2. Then deposit in KipuBank:
depositTokenAsUSD(TOKEN_AMOUNT, TOKEN_ADDRESS)

// Examples:
// USDC: depositTokenAsUSD(1000000000, "0x...USDC_ADDRESS") // 1,000 USDC
// DAI:  depositTokenAsUSD(1000000000000000000000, "0x...DAI_ADDRESS") // 1,000 DAI
// Note: WETH deposits will be rejected - use deposit() for ETH instead
```

### Making Withdrawals
```javascript
// All withdrawals are in USDC:
withdrawUSD(500000000) // 500 USDC (6 decimals)

// Automatic validations:
- USD limit per transaction ✓
- Sufficient balance ✓
- Always receive USDC regardless of original deposit token
```

### Public Queries (No Gas)
```javascript
// View user balance (all stored as USDC)
getUserBalance("0xYourAddress") → User's balance in USDC

// View bank statistics
getBankValueUSD() → Total USD value per internal accounting (sum of deposits)
getBankUSDCBalance() → Actual USDC tokens held by contract (real balance)
// Note: Both should match under normal conditions, differences may indicate
// direct transfers, swap residue, or accounting discrepancies
getDepositsCount() → Number of deposits
getWithdrawalsCount() → Number of withdrawals

// View configuration
getUniswapRouter() → Current Uniswap V2 Router address
getUSDCAddress() → Current USDC token address
getBankCapUSD() → Bank capacity limit
getWithdrawalLimitUSD() → Per-transaction withdrawal limit
```

## 📊 Events and Monitoring

### Emitted Events
- `Deposit(address indexed account, address indexed token, string tokenSymbol, uint256 originalAmount, uint256 usdValue)`
- `Withdraw(address indexed account, address indexed token, string tokenSymbol, uint256 originalAmount, uint256 usdValue)`
- `UniswapRouterUpdated(address indexed operator, address oldRouter, address newRouter)`
- `RoleGrantedByAdmin(address indexed admin, address indexed account, bytes32 indexed role)`

Events appear in the Remix console after each successful transaction and include detailed information about original amounts and USD values.

## 🛡️ Custom Errors

| Error | When It Occurs |
|-------|----------------|
| `ExceedsBankCapUSD` | Deposit exceeds bank's USD capacity |
| `ExceedsWithdrawLimitUSD` | Withdrawal exceeds USD limit per transaction |
| `InsufficientBalanceUSD` | Insufficient USD balance for withdrawal |
| `TransferFailed` | ETH transfer failure |
| `InvalidContract` | Invalid contract address |
| `ZeroAmount` | Attempted deposit/withdrawal with amount 0 |
| `BankPausedError` | Operation blocked by bank pause |
| `UseDepositForETH` | Attempted WETH deposit via `depositTokenAsUSD` (use `deposit()` instead) |

## 🧪 Test Cases

See **[USE_CASES.md](USE_CASES.md)** for detailed test cases including:

1. **✅ Valid ETH/USDC deposits**: With automatic USD conversions
2. **✅ Valid ETH/USDC withdrawals**: Validated against USD limits  
3. **❌ Exceed bankCapUSD**: Attempt to deposit more than total limit
4. **❌ Exceed withdrawalLimitUSD**: Attempt to withdraw more than per-transaction limit
5. **✅ Admin functions**: Pause/unpause bank, grant roles
6. **✅ Operator functions**: Update Uniswap Router address
7. **✅ State queries**: Balances, prices, statistics

**Recommended test configuration:**
- Withdrawal Limit: 1,000 USD
- Bank Cap: 5,000 USD  
- Fixed ETH price: $4,117.88 (for testing)

## 🔗 Auxiliary Contracts

### Circle.sol (USDC Stub)
- **Purpose**: Simulates USDC token for testing
- **Decimals**: 6 (same as real USDC)
- **Functions**: `mint()`, `decimals()`, standard ERC20

### Oracle.sol (Price Feed Stub)  
- **Purpose**: Simulates Chainlink ETH/USD oracle
- **Fixed price**: $4,117.88 (for consistent testing)
- **Decimals**: 8 (Chainlink standard)
- **Compatibility**: AggregatorV3Interface

### IOracle.sol
- **Purpose**: Interface for Chainlink compatibility
- **Functions**: `latestAnswer()`, `latestRoundData()`

## ⚖️ Design Trade-offs

### **ETH vs ERC20 Token Handling**

#### **ETH (Native Ether)**
- **Nature**: Native blockchain currency, NOT an ERC20 token
- **Function**: `deposit()` - marked as `payable`
- **How it works**: 
  - Receives ETH via `msg.value`
  - Internally treats as WETH for Uniswap swap
  - Uses `swapExactETHForTokens()` method
- ✅ **Benefits**: Direct ETH handling, no token approvals needed
- ⚠️ **Trade-offs**: Requires special handling, different swap mechanism

#### **ERC20 Tokens (Including WETH)**
- **Nature**: Smart contracts implementing ERC20 standard
- **Function**: `depositTokenAsUSD(amount, tokenAddress)` - NOT payable
- **How it works**:
  - Requires prior `approve()` transaction
  - Uses `safeTransferFrom()` to move tokens
  - Uses `swapExactTokensForTokens()` method
- ✅ **Benefits**: Standardized interface, wide token support
- ⚠️ **Trade-offs**: Requires two transactions (approve + deposit)

#### **WETH Special Case**
- **Protection**: `depositTokenAsUSD()` rejects WETH addresses
- **Reason**: Prevents user confusion between ETH and WETH deposits
- **Error**: `UseDepositForETH()` when WETH is attempted via wrong function
- ✅ **Benefits**: Clear separation of concerns, prevents mistakes
- ⚠️ **Trade-offs**: Users must understand ETH vs WETH distinction

### **Unified USDC Storage**
- ✅ **Benefit**: Simplified accounting, single withdrawal method
- ✅ **Benefit**: No price oracle dependency, market-rate conversions
- ⚠️ **Trade-off**: Users always receive USDC, not original token
- ⚠️ **Trade-off**: Depends on Uniswap liquidity and slippage

### **Uniswap Integration**
- ✅ **Benefit**: Real-time market prices, no oracle manipulation risk
- ✅ **Benefit**: Automatic liquidity discovery
- ⚠️ **Trade-off**: Requires direct USDC pairs (no multi-hop routing)
- ⚠️ **Trade-off**: Subject to DEX fees and slippage
- ⚠️ **Trade-off**: Failed swaps cause entire transaction to revert

### **Immutable Configuration**
- ✅ **Benefit**: Gas efficient, tamper-proof security for critical parameters
- ✅ **USDC Token**: Immutable to prevent balance manipulation after deployment
- ✅ **Limits**: Withdrawal and bank capacity limits set permanently
- ⚠️ **Trade-off**: Requires contract redeployment to change any immutable values

### **Role-Based Access**
- ✅ **Benefit**: Granular permissions, operational flexibility
- ⚠️ **Trade-off**: Additional complexity vs single-admin model

### **No ETH Send Protection**
- ✅ **Current State**: No `receive()` or `fallback()` functions
- ✅ **Benefit**: Accidental ETH sends to contract will fail and revert
- ⚠️ **Trade-off**: Users must use correct `deposit()` function

## 🔄 ETH vs ERC20 Token Guide

### **When to use `deposit()` (for ETH)**
- ✅ You want to deposit native ETH (Ether)
- ✅ You're sending ETH directly from your wallet
- ✅ You want one-step deposit (no approval needed)
- ❌ **DO NOT** use for WETH or any other token

### **When to use `depositTokenAsUSD()` (for ERC20s)**
- ✅ You want to deposit any ERC20 token (USDT, DAI, WBTC, etc.)
- ✅ You already have USDC and want to deposit it directly
- ✅ You have other tokens with direct USDC pairs on Uniswap
- ❌ **DO NOT** use for native ETH
- ❌ **DO NOT** use for WETH (contract will reject with `UseDepositForETH` error)

### **Key Differences**
| Aspect | `deposit()` | `depositTokenAsUSD()` |
|--------|-------------|----------------------|
| **Function type** | `payable` | NOT `payable` |
| **Accepts** | Native ETH only | Any ERC20 (except WETH) |
| **Approval needed** | No | Yes (call `approve()` first) |
| **Transactions** | 1 transaction | 2 transactions |
| **Swap method** | `swapExactETHForTokens` | `swapExactTokensForTokens` |
| **Gas cost** | Lower (1 tx) | Higher (2 tx) |

### **Common Mistakes to Avoid**
- ❌ Sending ETH to `depositTokenAsUSD()` (will fail - not payable)
- ❌ Using WETH address in `depositTokenAsUSD()` (will revert)
- ❌ Forgetting to approve ERC20 tokens before deposit
- ❌ Expecting to withdraw original token (always get USDC back)

## 📊 Balance Reconciliation

The contract provides two similar but distinct balance query functions:

### **`getBankValueUSD()` vs `getBankUSDCBalance()`**

| Function | Source | Purpose |
|----------|--------|---------|
| `getBankValueUSD()` | Internal accounting (`totalTokenDeposits`) | Tracks sum of all user deposits |
| `getBankUSDCBalance()` | USDC token contract | Actual USDC tokens held |

**Normal Conditions**: Both functions should return the same value.

**Potential Differences**:
- ✅ **Direct USDC transfers**: Someone sent USDC directly to contract
- ✅ **Swap residue**: Small amounts left from Uniswap slippage
- ✅ **Debugging tool**: Helps identify accounting discrepancies
- ✅ **Future extensibility**: Useful for fees, yield, or multi-token features

Use both functions to verify contract health and detect unusual conditions.

## ⚠️ Important Notes

- **Uniswap Dependency**: All swaps require direct token/USDC pairs on Uniswap V2
- **Slippage**: Market swaps subject to price impact and fees
- **USDC Storage**: All deposits converted to USDC, withdrawals always in USDC
- **Security**: Perform complete audit before production deployment
- **Testing**: Test with small amounts first to understand swap behavior

## � Code Quality & Best Practices

### **Recent Improvements (v3.0.0)**
- ✅ **Immutable Variables**: Critical storage variables now use `SCREAMING_SNAKE_CASE` convention
  - `USDC_TOKEN`: Immutable USDC contract address for security
  - `WITHDRAWAL_LIMIT_USD`: Immutable withdrawal limit per transaction
  - `BANK_CAP_USD`: Immutable total bank capacity
- ✅ **Compiler Warnings**: All compilation warnings resolved
- ✅ **Test Suite**: Comprehensive unit tests with proper state mutability
- ✅ **Code Style**: Adherence to Solidity style guide recommendations
- ✅ **Security Hardening**: Prevention of post-deployment configuration changes for critical parameters

### **Development Standards**
- **Solidity Version**: ^0.8.22 (latest stable features)
- **OpenZeppelin**: Latest security-audited contracts
- **Foundry**: Modern development and testing framework
- **Code Coverage**: Comprehensive test suite covering all functions
- **Documentation**: Complete NatSpec documentation for all functions

## �📄 License

- **KipuBank on Sepolia**: [0x0C113b99C0f55f321fB6d1B4FdDD975FCa1EDB13](https://sepolia.etherscan.io/address/0x0C113b99C0f55f321fB6d1B4FdDD975FCa1EDB13)
- **Custom USDC Token on Sepolia**: [0xc22c484da337f1d4be2cbf27fb1ed69fa772a240](https://sepolia.etherscan.io/address/0xc22c484da337f1d4be2cbf27fb1ed69fa772a240)
- **Custom Data Feed on Sepolia**: [0xcdb9f8df0e2224587035a0811a85ce94ec07e0ff](https://sepolia.etherscan.io/address/0xcdb9f8df0e2224587035a0811a85ce94ec07e0ff)
- **Custom fixed ETH Price**: $4,117.88 (411788170000 with 8 decimals)
- **Mint USDC from Custom Circle**: your_address, 10000000000
- **ETH/USD Chainlink Ethereum Sepolia**: [0x694AA1769357215DE4FAC081bf1f309aDC325306](https://sepolia.etherscan.io/address/0x694AA1769357215DE4FAC081bf1f309aDC325306)
- **USDC Ethereum Sepolia**: [0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238](https://sepolia.etherscan.io/address/0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238)

## 📄 License

MIT License - See `LICENSE` for complete details.

---

**⚠️ Important**: This contract is for educational purposes. Stub contracts (Circle, Oracle) are designed only for testing. Perform complete security audit before production use.
