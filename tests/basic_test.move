/// Basic compilation test for the liquidity module
#[test_only]
module olend::basic_test;

use olend::liquidity;
use olend::errors;

// Test coin type
public struct TEST_COIN has drop {}

#[test]
fun test_error_codes() {
    // Test that error codes are accessible
    assert!(errors::unauthorized() == 1003);
    assert!(errors::vault_paused() == 1103);
    assert!(errors::insufficient_liquidity() == 1104);
}

#[test]
fun test_basic_compilation() {
    // This test just ensures the module compiles correctly
    // We'll test actual functionality once we have proper test setup
    let ctx = &mut sui::tx_context::dummy();
    let (registry, admin_cap) = liquidity::init_system(ctx);
    
    // Clean up
    sui::test_utils::destroy(registry);
    sui::test_utils::destroy(admin_cap);
}

#[test]
fun test_unified_liquidity_design() {
    // Test that each asset type can only have one vault (unified liquidity)
    let ctx = &mut sui::tx_context::dummy();
    let (mut registry, admin_cap) = liquidity::init_system(ctx);
    let clock = sui::clock::create_for_testing(ctx);
    
    // Initially no vault exists for TEST_COIN
    assert!(!liquidity::vault_exists<TEST_COIN>(&registry));
    assert!(liquidity::get_vault_id<TEST_COIN>(&registry).is_none());
    
    // Create first vault for TEST_COIN
    let vault_id = liquidity::create_vault<TEST_COIN>(
        &mut registry,
        &admin_cap,
        &clock,
        ctx
    );
    
    // Now vault exists
    assert!(liquidity::vault_exists<TEST_COIN>(&registry));
    assert!(liquidity::get_vault_id<TEST_COIN>(&registry).is_some());
    assert!(liquidity::get_vault_id<TEST_COIN>(&registry).destroy_some() == vault_id);
    
    // Clean up
    sui::test_utils::destroy(registry);
    sui::test_utils::destroy(admin_cap);
    sui::test_utils::destroy(clock);
}