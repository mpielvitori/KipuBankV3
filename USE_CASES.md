# KipuBank Use Cases and Testing Guide

This document provides practical examples for testing KipuBank V3.3.0 using cast commands and Foundry scripts.

## Environment Setup

Configure your environment variables in `.env` file and load them:

```bash
# Load environment variables
source .env
```

### Verify Contract Deployment
Before testing, ensure KipuBank is properly deployed:

```bash
# Check if contract has code (should return bytecode, not empty)
cast code $KIPUBANK_ADDRESS --rpc-url $RPC_URL

# Check basic contract info
cast call $KIPUBANK_ADDRESS "VERSION()(string)" --rpc-url $RPC_URL
```

**Required Environment Variables:**
- `KIPUBANK_ADDRESS` - Your deployed KipuBank contract address
- `RPC_URL` - Your Ethereum RPC URL
- `USER_WALLET_ADDRESS` - User wallet address for testing
- `OPERATOR_WALLET_ADDRESS` - Operator wallet address for role testing
- `USDC_MAINNET` - USDC token address (0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)
- `LINK_MAINNET` - LINK token address (0x3E64Cd889482443324F91bFA9c84fE72A511f48A) 
- `WETH_MAINNET` - WETH token address (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
- `UNISWAP_V2_ROUTER_MAINNET` - Uniswap V2 Router address (0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)
- Private keys for testing accounts

<!-- Generate new test private keys if needed:
```bash
# Generate new test accounts
cast wallet new # Creates new random wallet with private key
cast wallet new-mnemonic # Creates mnemonic and derived accounts
``` -->

## Basic Balance Checking

### Using Cast Commands

Check user balance:
```bash
# Get raw balance (in USDC wei - 6 decimals)
cast call $KIPUBANK_ADDRESS "getUserBalance(address)(uint256)" $USER_WALLET_ADDRESS --rpc-url $RPC_URL
```

Check bank statistics:
```bash
# Bank total value
cast call $KIPUBANK_ADDRESS "getBankValueUSD()(uint256)" --rpc-url $RPC_URL

# USDC balance
cast call $KIPUBANK_ADDRESS "getBankUSDCBalance()(uint256)" --rpc-url $RPC_URL

# Bank capacity
cast call $KIPUBANK_ADDRESS "getBankCapUSD()(uint256)" --rpc-url $RPC_URL

# Withdrawal limit
cast call $KIPUBANK_ADDRESS "getWithdrawalLimitUSD()(uint256)" --rpc-url $RPC_URL
```

## Getting Test Tokens First

Before testing KipuBank functions, you need tokens. Since you have 10,000 ETH per test account, swap ETH for the tokens you need:

### Quick Token Acquisition

```bash
# Set deadline to 30 minutes from now (Unix timestamp)
DEADLINE=$(($(date +%s) + 1800))  # 30 minutes from now

# Get 2000+ USDC (swap 1 ETH)
cast send $UNISWAP_V2_ROUTER_MAINNET "swapExactETHForTokens(uint256,address[],address,uint256)" 0 "[$WETH_MAINNET,$USDC_MAINNET]" $USER_WALLET_ADDRESS $DEADLINE --value 1ether --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL

# Get 50+ LINK tokens (swap 0.5 ETH)
cast send $UNISWAP_V2_ROUTER_MAINNET "swapExactETHForTokens(uint256,address[],address,uint256)" 0 "[$WETH_MAINNET,$LINK_MAINNET]" $USER_WALLET_ADDRESS $DEADLINE --value 0.5ether --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL

# Check your new token balances
echo "USDC: $(($(cast call $USDC_MAINNET "balanceOf(address)" $USER_WALLET_ADDRESS --rpc-url $RPC_URL) / 1000000)) USDC"
echo "LINK: $(($(cast call $LINK_MAINNET "balanceOf(address)" $USER_WALLET_ADDRESS --rpc-url $RPC_URL) / 1000000000000000000)) LINK"
```

## KipuBank Function Testing

### User Functions
```bash
# 1. Deposit ETH directly (converts to USDC)
cast send $KIPUBANK_ADDRESS "deposit()" --value 0.1ether --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL

# 2. Deposit USDC (1000 USDC = 1000000000 wei, 6 decimals)
cast send $USDC_MAINNET "approve(address,uint256)" $KIPUBANK_ADDRESS 1000000000 --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL
cast send $KIPUBANK_ADDRESS "depositTokenAsUSD(uint256,address)" 1000000000 $USDC_MAINNET --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL

# 3. Deposit LINK (10 LINK = 10000000000000000000 wei, 18 decimals)
cast send $LINK_MAINNET "approve(address,uint256)" $KIPUBANK_ADDRESS 10000000000000000000 --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL
cast send $KIPUBANK_ADDRESS "depositTokenAsUSD(uint256,address)" 10000000000000000000 $LINK_MAINNET --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL

# 4. Check your balance
forge script script/UserHelper.s.sol --rpc-url $RPC_URL -s "checkUser(address)" $USER_WALLET_ADDRESS -vvv

# 5. Withdraw USD (50 USDC = 50000000 wei)
cast send $KIPUBANK_ADDRESS "withdrawUSD(uint256)" 50000000 --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL
```

### Admin Functions (ADMIN_ROLE)
```bash
# Pause/unpause the bank
cast send $KIPUBANK_ADDRESS "pauseBank()" --private-key $ADMIN_PRIVATE_KEY --rpc-url $RPC_URL
cast send $KIPUBANK_ADDRESS "unpauseBank()" --private-key $ADMIN_PRIVATE_KEY --rpc-url $RPC_URL

# Grant operator role to an address (ADMIN_ROLE required)
cast send $KIPUBANK_ADDRESS "grantOperatorRole(address)" $OPERATOR_WALLET_ADDRESS --private-key $ADMIN_PRIVATE_KEY --rpc-url $RPC_URL

# Check if address has operator role (using OpenZeppelin AccessControl)
cast call $KIPUBANK_ADDRESS "hasRole(bytes32,address)(bool)" 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929 $OPERATOR_WALLET_ADDRESS --rpc-url $RPC_URL
```

### Operator Functions (OPERATOR_ROLE)
```bash
# Note: First grant operator role using Admin Functions above

# Update bank cap (2000 USD = 2000000000 wei)
cast send $KIPUBANK_ADDRESS "updateBankCap(uint256)" 2000000000 --private-key $OPERATOR_PRIVATE_KEY --rpc-url $RPC_URL

# Update withdrawal limit (100 USD = 100000000 wei)
cast send $KIPUBANK_ADDRESS "updateWithdrawalLimit(uint256)" 100000000 --private-key $OPERATOR_PRIVATE_KEY --rpc-url $RPC_URL
```

## Simple Testing Workflow

```bash
# 1. Get tokens first
source .env

DEADLINE=$(($(date +%s) + 1800))  # 30 minutes from now

# Swap 1 ETH for USDC
cast send $UNISWAP_V2_ROUTER_MAINNET "swapExactETHForTokens(uint256,address[],address,uint256)" 0 "[$WETH_MAINNET,$USDC_MAINNET]" $USER_WALLET_ADDRESS $DEADLINE --value 1ether --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL

# 2. Deposit ETH directly
cast send $KIPUBANK_ADDRESS "deposit()" --value 0.1ether --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL

# 3. Deposit some USDC
USDC_BALANCE=$(cast call $USDC_MAINNET "balanceOf(address)" $USER_WALLET_ADDRESS --rpc-url $RPC_URL)
DEPOSIT_AMOUNT=$((USDC_BALANCE / 2))
cast send $USDC_MAINNET "approve(address,uint256)" $KIPUBANK_ADDRESS $DEPOSIT_AMOUNT --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL
cast send $KIPUBANK_ADDRESS "depositTokenAsUSD(uint256,address)" $DEPOSIT_AMOUNT $USDC_MAINNET --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL

# 4. Check your total balance
forge script script/UserHelper.s.sol --rpc-url $RPC_URL -s "checkUser(address)" $USER_WALLET_ADDRESS -vvv

# 5. Test withdrawal
cast send $KIPUBANK_ADDRESS "withdrawUSD(uint256)" 25000000 --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL
```

## Error Testing Scenarios

### Test Common Failures
```bash
# Try to withdraw more than limit (should fail)
cast send $KIPUBANK_ADDRESS "withdrawUSD(uint256)" 2000000000 --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL

# Try to deposit WETH (should fail - WETH not allowed)
cast send $WETH_MAINNET "approve(address,uint256)" $KIPUBANK_ADDRESS 1000000000000000000 --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL
cast send $KIPUBANK_ADDRESS "depositTokenAsUSD(uint256,address)" 1000000000000000000 $WETH_MAINNET --private-key $USER_PRIVATE_KEY --rpc-url $RPC_URL
```

## Quick Reference

### Check Balances
```bash
# User balance in KipuBank
cast call $KIPUBANK_ADDRESS "getUserBalance(address)" $USER_WALLET_ADDRESS --rpc-url $RPC_URL

# Token balances
cast call $USDC_MAINNET "balanceOf(address)" $USER_WALLET_ADDRESS --rpc-url $RPC_URL
cast call $LINK_MAINNET "balanceOf(address)" $USER_WALLET_ADDRESS --rpc-url $RPC_URL

# Bank status
cast call $KIPUBANK_ADDRESS "getBankValueUSD()" --rpc-url $RPC_URL
cast call $KIPUBANK_ADDRESS "getBankCapUSD()" --rpc-url $RPC_URL
```

### Using UserHelper Script
```bash
# Complete analysis
forge script script/UserHelper.s.sol --rpc-url $RPC_URL -vvv

# Check specific user
forge script script/UserHelper.s.sol --rpc-url $RPC_URL -s "checkUser(address)" $USER_WALLET_ADDRESS -vvv

# Bank statistics
forge script script/UserHelper.s.sol --rpc-url $RPC_URL -s "bankStats()" -vvv
```

### Token Decimals Reference
- **USDC**: 6 decimals (1 USDC = 1,000,000 wei)
- **LINK**: 18 decimals (1 LINK = 1,000,000,000,000,000,000 wei)  
- **ETH**: 18 decimals (1 ETH = 1,000,000,000,000,000,000 wei)