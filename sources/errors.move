/// Error codes for the Olend DeFi platform
/// Following Sui Move best practices with EPascalCase for error constants
module olend::errors;

// General errors (1000-1099) - private constants
/// Insufficient balance for the operation
const INSUFFICIENT_BALANCE: u64 = 1001;
/// Invalid amount provided
const INVALID_AMOUNT: u64 = 1002;
/// Unauthorized access attempt
const UNAUTHORIZED: u64 = 1003;
/// Operation is paused
const PAUSED: u64 = 1004;
/// Invalid parameter provided
const INVALID_PARAMETER: u64 = 1005;

// Vault errors (1100-1199) - private constants
/// Vault not found
const VAULT_NOT_FOUND: u64 = 1101;
/// Daily withdrawal limit exceeded
const DAILY_LIMIT_EXCEEDED: u64 = 1102;
/// Vault is paused
const VAULT_PAUSED: u64 = 1103;
/// Insufficient liquidity in vault
const INSUFFICIENT_LIQUIDITY: u64 = 1104;

// Lending errors (1200-1299)
/// Lending pool not found
const EPoolNotFound: u64 = 1201;
/// Deposit cap exceeded
const EDepositCapExceeded: u64 = 1202;
/// Below minimum deposit amount
const EBelowMinDeposit: u64 = 1203;
/// Below minimum withdrawal amount
const EBelowMinWithdraw: u64 = 1204;
/// YToken is collateralized and cannot be withdrawn
const EYTokenCollateralized: u64 = 1205;

// Borrowing errors (1300-1399)
/// Insufficient collateral for borrowing
const EInsufficientCollateral: u64 = 1301;
/// Exceeds borrowing limit
const EExceedsBorrowLimit: u64 = 1302;
/// Position not found
const EPositionNotFound: u64 = 1303;
/// Position is healthy and cannot be liquidated
const EPositionHealthy: u64 = 1304;
/// Interest rate is locked and cannot be modified
const ERateLocked: u64 = 1305;
/// Loan has matured
const ELoanMatured: u64 = 1306;

// Oracle errors (1400-1499)
/// Price data is stale
const EStalePrice: u64 = 1401;
/// Price deviation is too high
const EPriceDeviationTooHigh: u64 = 1402;
/// Oracle not found
const EOracleNotFound: u64 = 1403;
/// Price confidence is too low
const ELowConfidence: u64 = 1404;

// Liquidation errors (1500-1599)
/// Position is not liquidatable
const EPositionNotLiquidatable: u64 = 1501;
/// Liquidation failed
const ELiquidationFailed: u64 = 1502;
/// Insufficient DEX liquidity
const EInsufficientDexLiquidity: u64 = 1503;
/// Slippage is too high
const ESlippageTooHigh: u64 = 1504;

// Constants for error codes (accessible within module)
const EInsufficientBalance: u64 = 1001;
const EInvalidAmount: u64 = 1002;
const EUnauthorized: u64 = 1003;
const EPaused: u64 = 1004;
const EInvalidParameter: u64 = 1005;
const EVaultNotFound: u64 = 1101;
const EDailyLimitExceeded: u64 = 1102;
const EVaultPaused: u64 = 1103;
const EInsufficientLiquidity: u64 = 1104;

// Public getter functions for error codes
public fun insufficient_balance(): u64 { EInsufficientBalance }
public fun invalid_amount(): u64 { EInvalidAmount }
public fun unauthorized(): u64 { EUnauthorized }
public fun paused(): u64 { EPaused }
public fun invalid_parameter(): u64 { EInvalidParameter }

public fun vault_not_found(): u64 { EVaultNotFound }
public fun daily_limit_exceeded(): u64 { EDailyLimitExceeded }
public fun vault_paused(): u64 { EVaultPaused }
public fun insufficient_liquidity(): u64 { EInsufficientLiquidity }

public fun pool_not_found(): u64 { EPoolNotFound }
public fun deposit_cap_exceeded(): u64 { EDepositCapExceeded }
public fun below_min_deposit(): u64 { EBelowMinDeposit }
public fun below_min_withdraw(): u64 { EBelowMinWithdraw }
public fun ytoken_collateralized(): u64 { EYTokenCollateralized }

public fun insufficient_collateral(): u64 { EInsufficientCollateral }
public fun exceeds_borrow_limit(): u64 { EExceedsBorrowLimit }
public fun position_not_found(): u64 { EPositionNotFound }
public fun position_healthy(): u64 { EPositionHealthy }
public fun rate_locked(): u64 { ERateLocked }
public fun loan_matured(): u64 { ELoanMatured }

public fun stale_price(): u64 { EStalePrice }
public fun price_deviation_too_high(): u64 { EPriceDeviationTooHigh }
public fun oracle_not_found(): u64 { EOracleNotFound }
public fun low_confidence(): u64 { ELowConfidence }

public fun position_not_liquidatable(): u64 { EPositionNotLiquidatable }
public fun liquidation_failed(): u64 { ELiquidationFailed }
public fun insufficient_dex_liquidity(): u64 { EInsufficientDexLiquidity }
public fun slippage_too_high(): u64 { ESlippageTooHigh }