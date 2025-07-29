/// Lending module for deposit and withdrawal operations
/// Implements YToken-based share accounting system
module olend::lending;

use sui::object::UID;

// Module structure placeholder - will be implemented in later tasks
public struct LendingPool<phantom T> has key {
    id: UID,
}

public struct YToken<phantom T> has key, store {
    id: UID,
}

public struct InterestRateModel has store {
    base_rate: u64,
}