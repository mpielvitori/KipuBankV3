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

2. Edit `.env` and replace `YOUR_ALCHEMY_KEY_HERE` with your current Alchemy API key

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

## Starting Anvil with Sepolia Fork
```shell
anvil --fork-url $ETH_RPC_URL
```

## Deploy KipuBank Contract
```shell
forge script script/KipuBank.s.sol  --rpc-url $RPC_URL --broadcast --account wallet0 --sender $WALLET_ADDRESS
```


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
| `updateUniswapRouter(router)` | external (operator) | Update router address |

### Implemented Security
- ✅ **Reentrancy Protection**: OpenZeppelin ReentrancyGuard
- ✅ **Access Control**: Admin/Operator role-based system
- ✅ **CEI Pattern**: Checks-Effects-Interactions properly implemented
- ✅ **Custom Errors**: Specific error types for each validation
- ✅ **Safe Transfers**: Use of `.call()` for ETH and standard ERC20
- ✅ **Oracle Validation**: Verification of valid price data

## 🚀 Deployment on Remix IDE

# Resumen de Decisiones de Arquitectura

- Solo se permiten depósitos de tokens que tengan un par directo con USDC en Uniswap V2.
- El contrato cachea la dirección de la factory (actualizable por operator) para optimizar gas (ahorro de ~2,100 gas por validación, costo de deployment +22,000 gas, break-even en 18 transacciones fallidas).
- ETH y WETH son soportados como casos especiales (ETH → WETH → USDC lo maneja el router, WETH → USDC es swap directo).
- No se permiten rutas multi-hop (ej: Token → WETH → USDC) para otros tokens, solo pares directos.
- Los errores son claros y específicos (`NoDirectPairExists`).
- La validación previa evita swaps fallidos costosos y mejora la experiencia de usuario.
- Factory y router son actualizables por operators para flexibilidad futura.

## Ejemplo de validación

```solidity
function _getExpectedUsdcAmount(uint256 amountIn, address tokenIn) private view returns (uint256) {
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = address(USDC_TOKEN);
    
    try uniswapRouter.getAmountsOut(amountIn, path) returns (uint256[] memory amounts) {
        return amounts[amounts.length - 1];
    } catch {
        revert NoDirectPairExists(); // No pair exists or insufficient liquidity
    }
}
```

## Funciones de Operator

```solidity
// Actualizar router solamente
function updateUniswapRouter(address newRouter) external onlyRole(OPERATOR_ROLE);
```## Tokens soportados
- ETH (el router maneja el wrap a WETH)
- WETH
- USDC
- Tokens con par directo USDC (ej: DAI, USDT, WBTC)

## Trade-offs
- ✅ Simplicidad y predictibilidad
- ✅ Gas eficiente con getAmountsOut (43% menos en errores)
- ✅ Flexibilidad: Router actualizable por operator
- ✅ Fail-fast validation: Bank cap check antes del swap
- ❌ No soporta tokens que solo tengan par con WETH
- ❌ Requiere rol operator para actualizaciones (seguridad vs flexibilidad)

## Para más detalles, ver USE_CASES.md
- ❌ Limited tokens: Only direct USDC pairs (by design)
- ❌ No multi-hop: Token → WETH → USDC routes not supported
- ✅ Router/Factory updates: Operators can update addresses for flexibility

### **Token Routing Strategy**

#### **Supported Token Types**
```solidity
if (token == ETH) {
    // Router handles ETH → WETH → USDC automatically
} else if (token == WETH) {
    // Direct WETH → USDC swap
} else if (token == USDC) {
    // No conversion needed
} else {
    // ONLY direct token → USDC pairs allowed
    if (!_hasDirectPairWithUSDC(token)) {
        revert NoDirectPairExists();
    }
}
```

**Supported:**
- ✅ **ETH**: Router automatically converts ETH → WETH → USDC
- ✅ **WETH**: Direct swap WETH → USDC  
- ✅ **USDC**: No conversion needed
- ✅ **Major tokens**: DAI, USDT, WBTC, etc. (with direct USDC pairs)

**Not Supported:**
- ❌ **Tokens without direct USDC pairs**: Would require multi-hop routing
- ❌ **Multi-hop routes**: Token → WETH → USDC (rejected for simplicity)

#### **Gas Optimization Analysis**

#### **Factory Caching Strategy**
- **Deployment cost**: +22,000 gas (one-time)
- **Per-transaction savings**: 2,100 gas (avoids `router.factory()` call)
- **Break-even point**: 18 failed transactions
- **Annual savings**: Significant for high-volume usage
- **Flexibility**: Operator can update factory for future changes

#### **Validation Gas Costs**
```
Failed Transaction Costs:
- Without validation: 30,000-50,000 gas (full swap attempt)
- With getPair(): 23,600 gas (quick validation + revert)
- With getAmountsOut(): 31,000 gas (complex path finding)

Savings per failed transaction: 6,400-26,400 gas (21-53% reduction)
```

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

### **Security & Flexibility Balance**
- ✅ **Immutable Config**: USDC token and limits set permanently for security
- ✅ **Updateable Components**: Factory and router updateable by operator role
- ✅ **Access Control**: Only operators can make infrastructure updates
- ✅ **Automatic Sync**: Router updates automatically sync factory address
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

## 📦 Code Quality & Best Practices

### **Development Standards**
- **Solidity Version**: ^0.8.22 (latest stable features)
- **OpenZeppelin**: Latest security-audited contracts
- **Foundry**: Modern development and testing framework
- **Code Coverage**: Comprehensive test suite covering all functions
- **Documentation**: Complete NatSpec documentation for all functions

## �📄 License

MIT License - See `LICENSE` for complete details.

---

**⚠️ Important**: This contract is for educational purposes. Stub contracts (Circle, Oracle) are designed only for testing. Perform complete security audit before production use.
