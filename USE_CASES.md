# 🧪 **KipuBank Test Cases - Uniswap V2 Integration**

## � **Important Notes**

### **Balance Functions**
- `getBankValueUSD()`: Internal accounting (sum of tracked deposits)  
- `getBankUSDCBalance()`: Actual USDC tokens held by contract
- **Normal condition**: Both should return same value
- **Discrepancies**: May indicate direct transfers, swap residue, or issues

## �🔍 **Case 1: Verify Initial Configuration**

### **Actions to execute:**
```
// 1. Verify bank limits
getBankCapUSD() 
// Expected result: 5000000000 (5,000 USD with 6 decimals)

getWithdrawalLimitUSD()
// Expected result: 1000000000 (1,000 USD with 6 decimals)

// 2. Verify Uniswap integration
getUniswapRouter()
// Expected result: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D (Uniswap V2 Router)

getUSDCAddress()
// Expected result: USDC_TOKEN_ADDRESS

// 3. Verify initial state (both functions should match)
getBankValueUSD()
// Expected result: 0 (internal accounting)

getBankUSDCBalance()
// Expected result: 0 (actual USDC tokens)

paused()
// Expected result: false
```

## 🔍 **Case 2: ETH Deposit (Successful)**

### **Action:**
```
// Deposit 0.1 ETH (automatically swapped to USDC via Uniswap)
deposit()
// Value: 100000000000000000 (0.1 ETH in wei)
```

### **Expected results:**
```
getUserBalance(YOUR_ADDRESS)
// Expected result: Variable amount in USDC (depends on ETH/USDC market rate)

getBankValueUSD()
// Expected result: Same as user balance

getDepositsCount()
// Expected result: 1

getBankUSDCBalance()
// Expected result: Same as user balance (actual USDC tokens held)
```

### **Expected event:**
`Deposit(your_address, 0x000...000, "ETH", 100000000000000000, USDC_AMOUNT_RECEIVED)`

**Note:** USDC amount depends on current ETH/USDC market rate on Uniswap

## 🔍 **Case 3: ERC20 Token Deposit (USDC - No Swap)**

### **Preparation:**
```
// 1. First, approve USDC for KipuBank contract
// In USDC contract:
approve(KIPUBANK_ADDRESS, 1000000000)
// 1000000000 = 1,000 USDC (6 decimals)
```

### **Action:**
```
// 2. Deposit 1,000 USDC (no swap needed, already USDC)
depositTokenAsUSD(1000000000, USDC_ADDRESS)
```

### **Expected results:**
```
getUserBalance(YOUR_ADDRESS)
// Expected result: Previous balance + 1000000000

getBankValueUSD()
// Expected result: Previous total + 1000000000

getDepositsCount()
// Expected result: 2

getBankUSDCBalance()
// Expected result: Previous balance + 1000000000
```

### **Expected events:**
`Transfer(your_address, KIPUBANK_ADDRESS, 1000000000)`
`Deposit(your_address, USDC_ADDRESS, "USDC", 1000000000, 1000000000)`

## 🔍 **Case 4: ERC20 Token Deposit with Swap (e.g., DAI)**

### **Preparation:**
```
// 1. First, approve DAI (or other ERC20) for KipuBank contract
// In DAI contract:
approve(KIPUBANK_ADDRESS, 1000000000000000000000)
// 1000000000000000000000 = 1,000 DAI (18 decimals)
```

### **Action:**
```
// 2. Deposit 1,000 DAI (will be swapped to USDC via Uniswap)
depositTokenAsUSD(1000000000000000000000, DAI_ADDRESS)
```

### **Expected results:**
```
getUserBalance(YOUR_ADDRESS)
// Expected result: Previous balance + USDC_AMOUNT_FROM_SWAP

getBankValueUSD()
// Expected result: Previous total + USDC_AMOUNT_FROM_SWAP

getDepositsCount()
// Expected result: 3

getBankUSDCBalance()
// Expected result: Previous balance + USDC_AMOUNT_FROM_SWAP
```

### **Expected events:**
`Transfer(your_address, KIPUBANK_ADDRESS, 1000000000000000000000)`
`Deposit(your_address, DAI_ADDRESS, "DAI", 1000000000000000000000, USDC_AMOUNT_FROM_SWAP)`

**Note:** USDC amount depends on current DAI/USDC market rate on Uniswap

## 🔍 **Case 5: USDC Withdrawal (Successful)**

### **Action:**
```
// Withdraw 500 USDC (all withdrawals are in USDC)
withdrawUSD(500000000)
// 500000000 = 500 USDC (6 decimals)
```

### **Expected results:**
```
getUserBalance(YOUR_ADDRESS)
// Expected result: Previous balance - 500000000

getWithdrawalsCount()
// Expected result: 1

getBankValueUSD()
// Expected result: Previous total - 500000000

getBankUSDCBalance()
// Expected result: Previous balance - 500000000
```

### **Expected events:**
`Withdraw(your_address, USDC_ADDRESS, "USDC", 500000000, 500000000)`
`Transfer(KIPUBANK_ADDRESS, your_address, 500000000)`

---

## 🚫 **Case 6: WETH Deposit Rejection**

### **Action:**
```
// Attempt to deposit WETH via depositTokenAsUSD (should fail)
// 1. First approve WETH
approve(KIPUBANK_ADDRESS, 1000000000000000000) // 1 WETH

// 2. Try to deposit WETH
depositTokenAsUSD(1000000000000000000, WETH_ADDRESS)
```

### **Expected result:**
```
❌ Error: UseDepositForETH()
```

### **Note:**
Users should use `deposit()` function for ETH deposits, not `depositTokenAsUSD()` with WETH address.

---

## 🚫 **Case 7: Attempt to Exceed Withdrawal Limit**

### **Action:**
```
// Attempt to withdraw more than $1,000 USD limit
withdrawUSD(1500000000)
// 1500000000 = 1,500 USDC (exceeds 1,000 USD limit)
```

### **Expected result:**
```
❌ Error: ExceedsWithdrawLimitUSD

{
 "attemptedUSD": {
  "value": "1500000000",
  "documentation": "USD value attempted to withdraw"
 },
 "limitUSD": {
  "value": "1000000000",
  "documentation": "Maximum withdrawal limit in USD"
 }
}
```

---

## 🚫 **Case 8: Attempt to Exceed Bank Cap**

### **Preparation:**
```
// Calculate how much is left to reach $5,000 cap
getBankValueUSD()
// Suppose it returns current_balance
// Remaining: 5000000000 - current_balance
```

### **Action:**
```
// Attempt to deposit more USDC than allowed
// Try to deposit amount that would exceed cap
depositTokenAsUSD(LARGE_AMOUNT, USDC_ADDRESS)
```

### **Expected result:**
```
❌ Error: ExceedsBankCapUSD
{
 "attemptedUSD": {
  "value": "LARGE_AMOUNT",
  "documentation": "USD value attempted to deposit"
 },
 "availableUSD": {
  "value": "REMAINING_CAPACITY",
  "documentation": "Available USD capacity in the bank"
 }
}
```

---

## 🔍 **Case 9: Admin Functions**

### **Pause as NON-admin user:**
```
// As NON-admin user, pause the bank
pauseBank()
```

### **Expected result:**
```
❌ Error: AccessControlUnauthorizedAccount
{
 "account": {
  "value": "your_address"
 },
 "neededRole": {
  "value": "0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775"
 }
}
```

### **Pause as admin user:**
```
// As admin, pause the bank
pauseBank()
```

### **Verification:**
```
paused()
// Expected result: true

// Attempt to deposit with paused bank
deposit()
// Value: 10000000000000000 (0.01 ETH)
// Expected result: ❌ Error: EnforcedPause()
```

### **Expected event:**
`Paused(your_address)`

### **Unpause:**
```
unpauseBank()

paused()
// Expected result: false
```

### **Expected event:**
`Unpaused(your_address)`

---

## 🚫 **Case 10: Redundant Pause/Unpause Operations**

### **Attempt to pause already paused bank:**
```
// First pause the bank
pauseBank()

// Try to pause again (should fail)
pauseBank()
```

### **Expected result:**
```
❌ Error: EnforcedPause()
```

### **Attempt to unpause already unpaused bank:**
```
// First unpause the bank (if paused)
unpauseBank()

// Try to unpause again (should fail)
unpauseBank()
```

### **Expected result:**
```
❌ Error: ExpectedPause()
```

---

## 🔍 **Case 11: Operator Functions**

### **Grant operator role:**
```
// As admin, grant operator role to another account
grantOperatorRole(OPERATOR_ADDRESS)
```

### **Verification:**
```
OPERATOR_ROLE -> 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929
hasRole(OPERATOR_ROLE, OPERATOR_ADDRESS)
// Expected result: true
```

### **Expected events:**
`RoleGranted(OPERATOR_ROLE, OPERATOR_ADDRESS, ADMIN_ADDRESS)`
`RoleGrantedByAdmin(ADMIN_ADDRESS, OPERATOR_ADDRESS, OPERATOR_ROLE)`

---

## 🔍 **Case 11: Operator Functions**

### **Update Uniswap Router:**
```
// As operator, update the Uniswap Router
updateUniswapRouter(NEW_ROUTER_ADDRESS)
```

### **Verification:**
```
getUniswapRouter()
// Expected result: NEW_ROUTER_ADDRESS
```

### **Expected event:**
`UniswapRouterUpdated(your_address, OLD_ROUTER_ADDRESS, NEW_ROUTER_ADDRESS)`

### **Note on USDC Address:**
```
// The USDC token address is immutable and cannot be changed after deployment
// This prevents manipulation of user balances once deposits exist
getUSDCAddress()
// This will always return the original USDC address set at deployment
```

---

## 📊 **Quick Reference**

### **ETH amounts in wei:**
```
10000000000000000    // 0.01 ETH
50000000000000000    // 0.05 ETH  
100000000000000000   // 0.1 ETH
250000000000000000   // 0.25 ETH
1000000000000000000  // 1 ETH
```

### **USDC amounts (6 decimals):**
```
1000000     // 1 USDC
100000000   // 100 USDC
500000000   // 500 USDC
1000000000  // 1,000 USDC
5000000000  // 5,000 USDC
```

### **DAI amounts (18 decimals):**
```
1000000000000000000      // 1 DAI
100000000000000000000    // 100 DAI
1000000000000000000000   // 1,000 DAI
```

### **Special addresses:**
```
0x0000000000000000000000000000000000000000  // address(0) only for ETH in events (not used in balances)
USDC_ADDRESS   // Your USDC token address (where all balances are stored)
DAI_ADDRESS    // DAI token address (if testing token swaps)
WETH_ADDRESS   // WETH token address (for rejection test)
```

### **Key Differences from Previous Version:**
- ✅ All deposits converted to USDC and stored as USDC
- ✅ Only USDC withdrawals available (`withdrawUSD()`)
- ✅ ETH deposits via `deposit()` (payable)
- ✅ ERC20 deposits via `depositTokenAsUSD()` (requires approval)
- ✅ WETH deposits rejected with `UseDepositForETH()` error
- ✅ No price oracles - market rates via Uniswap
- ✅ Direct USDC pairs required for token swaps

### **Important Balance Storage Notes:**
- ✅ All user balances stored under `balances[user][USDC_ADDRESS]` internally
- ✅ `address(0)` only used in events to represent original ETH deposits
- ✅ Bidimensional mapping kept for future extensibility
- ✅ Use `getUserBalance(user)` to query user's USDC balance
- ✅ Function `getUserBalanceUSD` removed (was redundant)