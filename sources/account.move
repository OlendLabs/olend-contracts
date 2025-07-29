/// Account management module for user profiles and permissions
/// Implements user level system and account tracking
module olend::account;

use sui::object::UID;

// Module structure placeholder - will be implemented in later tasks
public struct AccountRegistry has key {
    id: UID,
}

public struct Account has key {
    id: UID,
}

public struct AccountCap has key {
    id: UID,
}