/// Oracle module for price data management
/// Integrates with Pyth Network and implements price aggregation
module olend::oracle;

use sui::object::UID;

// Module structure placeholder - will be implemented in later tasks
public struct PriceAggregator<phantom T> has key {
    id: UID,
}

public struct PriceData has store {
    price: u64,
}