/// Tests for the liquidity module
/// Following TDD approach with comprehensive test coverage
#[test_only]
module olend::liquidity_tests;

use sui::test_scenario::{Self as test, Scenario};
use sui::clock::{Self, Clock};
use sui::coin;
use sui::test_utils::destroy;
use olend::liquidity::{Self, Registry, AdminCap, Vault};

// Test coin type
public struct TEST_COIN has drop {}

// ======== Test Setup Helpers ========

fun setup_test(): (Scenario, Registry, AdminCap, Clock) {
    let mut scenario = test::begin(@0x1);
    let clock = clock::create_for_testing(scenario.ctx());
    let (registry, admin_cap) = liquidity::init_system(scenario.ctx());
    
    (scenario, registry, admin_cap, clock)
}

// ======== Initialization Tests ========

#[test]
fun test_init_system_creates_registry_and_admin_cap() {
    let mut scenario = test::begin(@0x1);
    let (registry, admin_cap) = liquidity::init_system(scenario.ctx());
    
    // Verify objects are created properly
    assert!(sui::object::id(&admin_cap) != sui::object::id(&registry));
    
    destroy(registry);
    destroy(admin_cap);
    scenario.end();
}

// ======== Vault Creation Tests ========

#[test]
fun test_create_vault_success() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    let vault_id = liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    // Verify vault ID is valid
    assert!(vault_id != sui::object::id_from_address(@0x0));
    
    destroy(registry);
    destroy(admin_cap);
    destroy(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = 1003)]
fun test_create_vault_unauthorized_fails() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    // Create another admin cap to test unauthorized access
    let (fake_registry, fake_admin_cap) = liquidity::init_system(scenario.ctx());
    
    liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &fake_admin_cap,
        &clock,
        scenario.ctx()
    );
    
    destroy(registry);
    destroy(admin_cap);
    destroy(fake_registry);
    destroy(fake_admin_cap);
    destroy(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = 1005)]
fun test_create_duplicate_vault_fails() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    // Create first vault
    liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    // Try to create duplicate vault - should fail
    liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    destroy(registry);
    destroy(admin_cap);
    destroy(clock);
    scenario.end();
}

// ======== Vault Management Tests ========

#[test]
fun test_pause_and_resume_vault() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    // Create vault first
    let vault_id = liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    scenario.next_tx(@0x1);
    
    // Get the vault object
    let mut vault = scenario.take_shared_by_id<Vault<TEST_COIN>>(vault_id);
    
    // Initially vault should not be paused
    assert!(!liquidity::is_paused(&vault));
    
    // Pause vault
    liquidity::pause_vault(
        &mut vault,
        &admin_cap,
        &registry,
        &clock,
        scenario.ctx()
    );
    
    // Verify vault is paused
    assert!(liquidity::is_paused(&vault));
    
    // Resume vault
    liquidity::resume_vault(
        &mut vault,
        &admin_cap,
        &registry,
        &clock,
        scenario.ctx()
    );
    
    // Verify vault is not paused
    assert!(!liquidity::is_paused(&vault));
    
    test::return_shared(vault);
    destroy(registry);
    destroy(admin_cap);
    destroy(clock);
    scenario.end();
}

#[test]
fun test_set_daily_limit() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    // Create vault first
    let vault_id = liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    scenario.next_tx(@0x1);
    
    // Get the vault object
    let mut vault = scenario.take_shared_by_id<Vault<TEST_COIN>>(vault_id);
    
    // Initially no daily limit
    let (limit, withdrawn, _) = liquidity::daily_limit_info(&vault);
    assert!(limit == 0);
    assert!(withdrawn == 0);
    
    // Set daily limit
    let new_limit = 1000;
    liquidity::set_daily_limit(
        &mut vault,
        &admin_cap,
        &registry,
        new_limit,
        &clock,
        scenario.ctx()
    );
    
    // Verify limit is set
    let (limit, withdrawn, _) = liquidity::daily_limit_info(&vault);
    assert!(limit == new_limit);
    assert!(withdrawn == 0);
    
    test::return_shared(vault);
    destroy(registry);
    destroy(admin_cap);
    destroy(clock);
    scenario.end();
}

// ======== Deposit and Withdrawal Tests ========

#[test]
fun test_deposit_and_withdraw_basic() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    // Create vault first
    let vault_id = liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    scenario.next_tx(@0x1);
    
    // Get the vault object
    let mut vault = scenario.take_shared_by_id<Vault<TEST_COIN>>(vault_id);
    
    // Create test coin for deposit
    let deposit_amount = 1000;
    let test_coin = coin::mint_for_testing<TEST_COIN>(deposit_amount, scenario.ctx());
    
    // Deposit assets
    let shares_minted = liquidity::deposit(
        &mut vault,
        test_coin,
        &registry,
        &clock,
        scenario.ctx()
    );
    
    // For first deposit, shares should equal deposit amount (1:1 ratio)
    assert!(shares_minted == deposit_amount);
    
    // Check vault info
    let (balance, total_shares, _asset_per_share) = liquidity::vault_info(&vault);
    assert!(balance == deposit_amount);
    assert!(total_shares == deposit_amount);
    
    // Withdraw half the assets
    let withdraw_shares = shares_minted / 2;
    let withdrawn_coin = liquidity::withdraw(
        &mut vault,
        withdraw_shares,
        &clock,
        scenario.ctx()
    );
    
    // Verify withdrawal amount
    assert!(withdrawn_coin.value() == deposit_amount / 2);
    
    // Check updated vault info
    let (balance, total_shares, _) = liquidity::vault_info(&vault);
    assert!(balance == deposit_amount / 2);
    assert!(total_shares == deposit_amount / 2);
    
    destroy(withdrawn_coin);
    test::return_shared(vault);
    destroy(registry);
    destroy(admin_cap);
    destroy(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = 1103)]
fun test_deposit_when_paused_fails() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    // Create vault first
    let vault_id = liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    scenario.next_tx(@0x1);
    
    // Get the vault object
    let mut vault = scenario.take_shared_by_id<Vault<TEST_COIN>>(vault_id);
    
    // Pause vault
    liquidity::pause_vault(
        &mut vault,
        &admin_cap,
        &registry,
        &clock,
        scenario.ctx()
    );
    
    // Try to deposit - should fail
    let test_coin = coin::mint_for_testing<TEST_COIN>(1000, scenario.ctx());
    liquidity::deposit(
        &mut vault,
        test_coin,
        &registry,
        &clock,
        scenario.ctx()
    );
    
    test::return_shared(vault);
    destroy(registry);
    destroy(admin_cap);
    destroy(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = 1102)]
fun test_withdraw_exceeds_daily_limit_fails() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    // Create vault first
    let vault_id = liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    scenario.next_tx(@0x1);
    
    // Get the vault object
    let mut vault = scenario.take_shared_by_id<Vault<TEST_COIN>>(vault_id);
    
    // Set daily limit
    let daily_limit = 500;
    liquidity::set_daily_limit(
        &mut vault,
        &admin_cap,
        &registry,
        daily_limit,
        &clock,
        scenario.ctx()
    );
    
    // Deposit assets
    let deposit_amount = 1000;
    let test_coin = coin::mint_for_testing<TEST_COIN>(deposit_amount, scenario.ctx());
    let shares_minted = liquidity::deposit(
        &mut vault,
        test_coin,
        &registry,
        &clock,
        scenario.ctx()
    );
    
    // Try to withdraw more than daily limit - should fail
    let withdraw_shares = shares_minted * 3 / 4; // 750 assets, exceeds 500 limit
    let _withdrawn_coin = liquidity::withdraw(
        &mut vault,
        withdraw_shares,
        &clock,
        scenario.ctx()
    );
    destroy(_withdrawn_coin);
    
    test::return_shared(vault);
    destroy(registry);
    destroy(admin_cap);
    destroy(clock);
    scenario.end();
}

// ======== Borrow and Repay Tests ========

#[test]
fun test_borrow_and_repay_basic() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    // Create vault first
    let vault_id = liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    scenario.next_tx(@0x1);
    
    // Get the vault object
    let mut vault = scenario.take_shared_by_id<Vault<TEST_COIN>>(vault_id);
    
    // Deposit assets first to have liquidity
    let deposit_amount = 1000;
    let test_coin = coin::mint_for_testing<TEST_COIN>(deposit_amount, scenario.ctx());
    liquidity::deposit(
        &mut vault,
        test_coin,
        &registry,
        &clock,
        scenario.ctx()
    );
    
    // Borrow assets
    let borrow_amount = 300;
    let borrowed_coin = liquidity::borrow(
        &mut vault,
        borrow_amount,
        &clock,
        scenario.ctx()
    );
    
    // Verify borrowed amount
    assert!(borrowed_coin.value() == borrow_amount);
    
    // Check vault balance decreased
    let (balance, _, _) = liquidity::vault_info(&vault);
    assert!(balance == deposit_amount - borrow_amount);
    
    // Repay the borrowed amount
    let repaid_amount = liquidity::repay(
        &mut vault,
        borrowed_coin,
        &clock,
        scenario.ctx()
    );
    
    // Verify repayment
    assert!(repaid_amount == borrow_amount);
    
    // Check vault balance restored
    let (balance, _, _) = liquidity::vault_info(&vault);
    assert!(balance == deposit_amount);
    
    test::return_shared(vault);
    destroy(registry);
    destroy(admin_cap);
    destroy(clock);
    scenario.end();
}

#[test, expected_failure(abort_code = 1104)]
fun test_borrow_insufficient_liquidity_fails() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    // Create vault first
    let vault_id = liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    scenario.next_tx(@0x1);
    
    // Get the vault object
    let mut vault = scenario.take_shared_by_id<Vault<TEST_COIN>>(vault_id);
    
    // Try to borrow from empty vault - should fail
    let _borrowed_coin = liquidity::borrow(
        &mut vault,
        1000,
        &clock,
        scenario.ctx()
    );
    destroy(_borrowed_coin);
    
    test::return_shared(vault);
    destroy(registry);
    destroy(admin_cap);
    destroy(clock);
    scenario.end();
}

// ======== Share Calculation Tests ========

#[test]
fun test_share_calculations() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    // Create vault first
    let vault_id = liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    scenario.next_tx(@0x1);
    
    // Get the vault object
    let mut vault = scenario.take_shared_by_id<Vault<TEST_COIN>>(vault_id);
    
    // Test initial state - empty vault
    let shares_for_1000 = liquidity::calculate_shares(&vault, 1000);
    assert!(shares_for_1000 == 1000); // 1:1 ratio for empty vault
    
    // Deposit some assets
    let _deposit_amount = 1000;
    let test_coin = coin::mint_for_testing<TEST_COIN>(_deposit_amount, scenario.ctx());
    liquidity::deposit(
        &mut vault,
        test_coin,
        &registry,
        &clock,
        scenario.ctx()
    );
    
    // Test calculations after deposit
    let shares_for_500 = liquidity::calculate_shares(&vault, 500);
    let assets_for_500_shares = liquidity::calculate_assets(&vault, 500);
    
    // Should maintain 1:1 ratio initially
    assert!(shares_for_500 == 500);
    assert!(assets_for_500_shares == 500);
    
    test::return_shared(vault);
    destroy(registry);
    destroy(admin_cap);
    destroy(clock);
    scenario.end();
}

// ======== System Pause Tests ========

#[test]
fun test_system_pause_and_resume() {
    let (mut scenario, mut registry, admin_cap, clock) = setup_test();
    
    // Initially system should not be paused
    // We can test this by creating a vault successfully
    let vault_id = liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    // Pause system
    liquidity::pause_system(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    // Resume system
    liquidity::resume_system(
        &mut registry,
        &admin_cap,
        &clock,
        scenario.ctx()
    );
    
    // Clean up - vault was created as shared object
    scenario.next_tx(@0x1);
    let vault = scenario.take_shared_by_id<Vault<TEST_COIN>>(vault_id);
    test::return_shared(vault);
    
    destroy(registry);
    destroy(admin_cap);
    destroy(clock);
    scenario.end();
}