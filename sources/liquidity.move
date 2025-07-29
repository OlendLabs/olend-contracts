/// Liquidity management module for Olend DeFi platform
/// Implements unified liquidity management with ERC-4626 compatibility
module olend::liquidity;

use sui::table::{Self, Table};
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::clock::{Self, Clock};
use sui::object::{Self, UID, ID};
use sui::transfer;
use sui::tx_context::TxContext;
use std::type_name::{Self, TypeName};
use std::option::{Self, Option};

// ======== Constants ========

/// Scaling factor for share calculations (1e18)
const SHARE_SCALING_FACTOR: u128 = 1_000_000_000_000_000_000;

/// Seconds in a day for daily limit reset
const SECONDS_PER_DAY: u64 = 86400;

// ======== Structs ========

/// Global registry for all asset vaults
public struct Registry has key {
    id: UID,
    /// Mapping from asset type to vault ID
    vaults: Table<TypeName, ID>,
    /// Reference to admin capability
    admin_cap: ID,
    /// Global pause state
    paused: bool,
}

/// Administrative capability for vault management
public struct AdminCap has key {
    id: UID,
}

/// Unified liquidity vault for a specific asset type
/// Implements ERC-4626 standard for share-based accounting
public struct Vault<phantom T> has key {
    id: UID,
    /// Asset balance held in the vault
    balance: Balance<T>,
    /// Total shares issued
    total_shares: u64,
    
    // State control
    /// Individual vault pause state
    paused: bool,
    
    // Daily limit control
    /// Daily withdrawal limit in asset units
    daily_withdraw_limit: u64,
    /// Amount withdrawn today
    daily_withdrawn: u64,
    /// Last reset timestamp (in seconds)
    last_reset_day: u64,
    
    // ERC-4626 compatibility
    /// Asset per share ratio (scaled by SHARE_SCALING_FACTOR)
    asset_per_share: u128,
    
    // Statistics
    /// Total deposits ever made
    total_deposits: u64,
    /// Total borrows ever made
    total_borrows: u64,
    
    // Metadata
    /// Vault creation timestamp
    created_at: u64,
}

// ======== Events ========

/// Emitted when a new vault is created
public struct VaultCreated has copy, drop {
    vault_id: ID,
    asset_type: TypeName,
    creator: address,
    timestamp: u64,
}

/// Emitted when vault is paused or unpaused
public struct VaultPauseStateChanged has copy, drop {
    vault_id: ID,
    paused: bool,
    admin: address,
    timestamp: u64,
}

/// Emitted when daily limit is updated
public struct DailyLimitUpdated has copy, drop {
    vault_id: ID,
    old_limit: u64,
    new_limit: u64,
    admin: address,
    timestamp: u64,
}

/// Emitted when assets are deposited
public struct AssetsDeposited has copy, drop {
    vault_id: ID,
    depositor: address,
    asset_amount: u64,
    shares_minted: u64,
    timestamp: u64,
}

/// Emitted when assets are withdrawn
public struct AssetsWithdrawn has copy, drop {
    vault_id: ID,
    withdrawer: address,
    asset_amount: u64,
    shares_burned: u64,
    timestamp: u64,
}

/// Emitted when assets are borrowed
public struct AssetsBorrowed has copy, drop {
    vault_id: ID,
    borrower: address,
    amount: u64,
    timestamp: u64,
}

/// Emitted when assets are repaid
public struct AssetsRepaid has copy, drop {
    vault_id: ID,
    repayer: address,
    amount: u64,
    timestamp: u64,
}

/// Emitted when system pause state changes
public struct SystemPauseStateChanged has copy, drop {
    paused: bool,
    admin: address,
    timestamp: u64,
}

// ======== Public Functions ========

/// Initialize the liquidity system
/// Creates the global registry and admin capability
public fun init_system(ctx: &mut TxContext): (Registry, AdminCap) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };
    
    let registry = Registry {
        id: object::new(ctx),
        vaults: table::new(ctx),
        admin_cap: object::id(&admin_cap),
        paused: false,
    };
    
    (registry, admin_cap)
}

/// Create a new vault for asset type T
public fun create_vault<T>(
    registry: &mut Registry,
    admin_cap: &AdminCap,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    // Verify admin capability
    assert!(object::id(admin_cap) == registry.admin_cap, olend::errors::unauthorized());
    
    let asset_type = type_name::get<T>();
    
    // Ensure vault doesn't already exist for this asset type
    assert!(!registry.vaults.contains(asset_type), olend::errors::invalid_parameter());
    
    let vault = Vault<T> {
        id: object::new(ctx),
        balance: balance::zero<T>(),
        total_shares: 0,
        paused: false,
        daily_withdraw_limit: 0, // No limit by default
        daily_withdrawn: 0,
        last_reset_day: clock.timestamp_ms() / 1000 / SECONDS_PER_DAY,
        asset_per_share: SHARE_SCALING_FACTOR, // 1:1 ratio initially
        total_deposits: 0,
        total_borrows: 0,
        created_at: clock.timestamp_ms() / 1000,
    };
    
    let vault_id = object::id(&vault);
    
    // Add to registry
    registry.vaults.add(asset_type, vault_id);
    
    // Emit event
    sui::event::emit(VaultCreated {
        vault_id,
        asset_type,
        creator: ctx.sender(),
        timestamp: clock.timestamp_ms() / 1000,
    });
    
    // Transfer vault to shared object
    transfer::share_object(vault);
    
    vault_id
}

/// Pause a vault (admin only)
public fun pause_vault<T>(
    vault: &mut Vault<T>,
    admin_cap: &AdminCap,
    registry: &Registry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Verify admin capability
    assert!(object::id(admin_cap) == registry.admin_cap, olend::errors::unauthorized());
    
    vault.paused = true;
    
    sui::event::emit(VaultPauseStateChanged {
        vault_id: object::id(vault),
        paused: true,
        admin: ctx.sender(),
        timestamp: clock.timestamp_ms() / 1000,
    });
}

/// Resume a vault (admin only)
public fun resume_vault<T>(
    vault: &mut Vault<T>,
    admin_cap: &AdminCap,
    registry: &Registry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Verify admin capability
    assert!(object::id(admin_cap) == registry.admin_cap, olend::errors::unauthorized());
    
    vault.paused = false;
    
    sui::event::emit(VaultPauseStateChanged {
        vault_id: object::id(vault),
        paused: false,
        admin: ctx.sender(),
        timestamp: clock.timestamp_ms() / 1000,
    });
}

/// Set daily withdrawal limit (admin only)
public fun set_daily_limit<T>(
    vault: &mut Vault<T>,
    admin_cap: &AdminCap,
    registry: &Registry,
    limit: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Verify admin capability
    assert!(object::id(admin_cap) == registry.admin_cap, olend::errors::unauthorized());
    
    let old_limit = vault.daily_withdraw_limit;
    vault.daily_withdraw_limit = limit;
    
    sui::event::emit(DailyLimitUpdated {
        vault_id: object::id(vault),
        old_limit,
        new_limit: limit,
        admin: ctx.sender(),
        timestamp: clock.timestamp_ms() / 1000,
    });
}

/// Pause the entire system (admin only)
public fun pause_system(
    registry: &mut Registry,
    admin_cap: &AdminCap,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Verify admin capability
    assert!(object::id(admin_cap) == registry.admin_cap, olend::errors::unauthorized());
    
    registry.paused = true;
    
    sui::event::emit(SystemPauseStateChanged {
        paused: true,
        admin: ctx.sender(),
        timestamp: clock.timestamp_ms() / 1000,
    });
}

/// Resume the entire system (admin only)
public fun resume_system(
    registry: &mut Registry,
    admin_cap: &AdminCap,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Verify admin capability
    assert!(object::id(admin_cap) == registry.admin_cap, olend::errors::unauthorized());
    
    registry.paused = false;
    
    sui::event::emit(SystemPauseStateChanged {
        paused: false,
        admin: ctx.sender(),
        timestamp: clock.timestamp_ms() / 1000,
    });
}

// ======== Package-only Functions ========

/// Deposit assets into vault and return shares minted
/// This function is only callable from within the package
public(package) fun deposit<T>(
    vault: &mut Vault<T>,
    asset: Coin<T>,
    registry: &Registry,
    clock: &Clock,
    ctx: &mut TxContext,
): u64 {
    // Check if system is globally paused
    assert!(!registry.paused, olend::errors::paused());
    // Check if vault is paused
    assert!(!vault.paused, olend::errors::vault_paused());
    
    let asset_amount = asset.value();
    assert!(asset_amount > 0, olend::errors::invalid_amount());
    
    // Reset daily limit if needed
    reset_daily_limit_if_needed(vault, clock);
    
    // Calculate shares to mint
    let shares_to_mint = calculate_shares_to_mint(vault, asset_amount);
    
    // Add asset to vault balance
    vault.balance.join(asset.into_balance());
    
    // Update vault state
    vault.total_shares = vault.total_shares + shares_to_mint;
    vault.total_deposits = vault.total_deposits + asset_amount;
    
    // Update asset per share ratio
    update_asset_per_share_ratio(vault);
    
    // Emit event
    sui::event::emit(AssetsDeposited {
        vault_id: object::id(vault),
        depositor: ctx.sender(),
        asset_amount,
        shares_minted: shares_to_mint,
        timestamp: clock.timestamp_ms() / 1000,
    });
    
    shares_to_mint
}

/// Withdraw assets from vault by burning shares
/// This function is only callable from within the package
public(package) fun withdraw<T>(
    vault: &mut Vault<T>,
    shares: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<T> {
    // Check if vault is paused
    assert!(!vault.paused, olend::errors::vault_paused());
    assert!(shares > 0, olend::errors::invalid_amount());
    assert!(shares <= vault.total_shares, olend::errors::insufficient_balance());
    
    // Reset daily limit if needed
    reset_daily_limit_if_needed(vault, clock);
    
    // Calculate asset amount to withdraw
    let asset_amount = calculate_assets_from_shares(vault, shares);
    
    // Check daily withdrawal limit
    if (vault.daily_withdraw_limit > 0) {
        assert!(
            vault.daily_withdrawn + asset_amount <= vault.daily_withdraw_limit,
            olend::errors::daily_limit_exceeded()
        );
        vault.daily_withdrawn = vault.daily_withdrawn + asset_amount;
    };
    
    // Check if vault has sufficient balance
    assert!(vault.balance.value() >= asset_amount, olend::errors::insufficient_liquidity());
    
    // Update vault state
    vault.total_shares = vault.total_shares - shares;
    
    // Update asset per share ratio
    update_asset_per_share_ratio(vault);
    
    // Extract assets from vault
    let withdrawn_balance = vault.balance.split(asset_amount);
    let withdrawn_coin = withdrawn_balance.into_coin(ctx);
    
    // Emit event
    sui::event::emit(AssetsWithdrawn {
        vault_id: object::id(vault),
        withdrawer: ctx.sender(),
        asset_amount,
        shares_burned: shares,
        timestamp: clock.timestamp_ms() / 1000,
    });
    
    withdrawn_coin
}

/// Borrow assets from vault
/// This function is only callable from within the package
public(package) fun borrow<T>(
    vault: &mut Vault<T>,
    amount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<T> {
    // Check if vault is paused
    assert!(!vault.paused, olend::errors::vault_paused());
    assert!(amount > 0, olend::errors::invalid_amount());
    
    // Check if vault has sufficient balance
    assert!(vault.balance.value() >= amount, olend::errors::insufficient_liquidity());
    
    // Update vault state
    vault.total_borrows = vault.total_borrows + amount;
    
    // Extract assets from vault
    let borrowed_balance = vault.balance.split(amount);
    let borrowed_coin = borrowed_balance.into_coin(ctx);
    
    // Emit event
    sui::event::emit(AssetsBorrowed {
        vault_id: object::id(vault),
        borrower: ctx.sender(),
        amount,
        timestamp: clock.timestamp_ms() / 1000,
    });
    
    borrowed_coin
}

/// Repay assets to vault
/// This function is only callable from within the package
public(package) fun repay<T>(
    vault: &mut Vault<T>,
    repayment: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
): u64 {
    let repay_amount = repayment.value();
    assert!(repay_amount > 0, olend::errors::invalid_amount());
    
    // Add repayment to vault balance
    vault.balance.join(repayment.into_balance());
    
    // Emit event
    sui::event::emit(AssetsRepaid {
        vault_id: object::id(vault),
        repayer: ctx.sender(),
        amount: repay_amount,
        timestamp: clock.timestamp_ms() / 1000,
    });
    
    repay_amount
}

// ======== View Functions ========

/// Get vault information
public fun vault_info<T>(vault: &Vault<T>): (u64, u64, u128) {
    (vault.balance.value(), vault.total_shares, vault.asset_per_share)
}

/// Calculate shares to mint for given asset amount
public fun calculate_shares<T>(vault: &Vault<T>, amount: u64): u64 {
    calculate_shares_to_mint(vault, amount)
}

/// Calculate assets to withdraw for given shares
public fun calculate_assets<T>(vault: &Vault<T>, shares: u64): u64 {
    calculate_assets_from_shares(vault, shares)
}

/// Check if vault is paused
public fun is_paused<T>(vault: &Vault<T>): bool {
    vault.paused
}

/// Get daily withdrawal limit info
public fun daily_limit_info<T>(vault: &Vault<T>): (u64, u64, u64) {
    (vault.daily_withdraw_limit, vault.daily_withdrawn, vault.last_reset_day)
}

/// Get vault ID for a specific asset type from registry
public fun get_vault_id<T>(registry: &Registry): Option<ID> {
    let asset_type = type_name::get<T>();
    if (registry.vaults.contains(asset_type)) {
        option::some(*registry.vaults.borrow(asset_type))
    } else {
        option::none()
    }
}

/// Check if a vault exists for the given asset type
public fun vault_exists<T>(registry: &Registry): bool {
    let asset_type = type_name::get<T>();
    registry.vaults.contains(asset_type)
}

// ======== Private Helper Functions ========

/// Calculate shares to mint based on current vault state
fun calculate_shares_to_mint<T>(vault: &Vault<T>, asset_amount: u64): u64 {
    if (vault.total_shares == 0) {
        // First deposit: 1:1 ratio
        asset_amount
    } else {
        // Calculate based on current asset per share ratio
        let shares = ((asset_amount as u128) * SHARE_SCALING_FACTOR) / vault.asset_per_share;
        (shares as u64)
    }
}

/// Calculate assets to withdraw based on shares
fun calculate_assets_from_shares<T>(vault: &Vault<T>, shares: u64): u64 {
    if (vault.total_shares == 0) {
        0
    } else {
        let assets = ((shares as u128) * vault.asset_per_share) / SHARE_SCALING_FACTOR;
        (assets as u64)
    }
}

/// Update the asset per share ratio
fun update_asset_per_share_ratio<T>(vault: &mut Vault<T>) {
    if (vault.total_shares > 0) {
        vault.asset_per_share = ((vault.balance.value() as u128) * SHARE_SCALING_FACTOR) / (vault.total_shares as u128);
    } else {
        vault.asset_per_share = SHARE_SCALING_FACTOR;
    }
}

/// Reset daily withdrawal limit if a new day has started
fun reset_daily_limit_if_needed<T>(vault: &mut Vault<T>, clock: &Clock) {
    let current_day = clock.timestamp_ms() / 1000 / SECONDS_PER_DAY;
    if (current_day > vault.last_reset_day) {
        vault.daily_withdrawn = 0;
        vault.last_reset_day = current_day;
    }
}