# User Module Documentation

## Overview
The `user.move` module manages user profiles, letter inventories, and social features for the Suimming game.

## Data Structures

### UserProfile
```move
public struct UserProfile has key, store {
    id: UID,
    created_epoch: u64,
    display_name: Option<String>,
    bio: Option<String>,
    letter_bank: String,           // Concatenated letters (e.g., "HELLO")
    visit_count_total: u64,
    visits: UID,                   // Dynamic field: address → VisitStat
    boast_checkpoint: Option<address>,
    walrus_items: UID,             // Dynamic field: bytes → WalrusItem
}
```

### VisitStat
```move
public struct VisitStat has store, drop {
    count: u64,
    last_epoch: u64,
}
```

### WalrusItem
```move
public struct WalrusItem has store, drop {
    cid_or_id: String,
    kind: u8,                      // 0=text, 1=image, 2=other
    note: String,
    created_epoch: u64,
}
```

## Public Functions

### `create_profile(ctx: &mut TxContext)`
Creates a new user profile.
- **Events**: `ProfileCreated { owner }`

### `update_profile(profile: &mut UserProfile, display_name: Option<String>, bio: Option<String>, _ctx: &mut TxContext)`
Updates profile display name and bio.

### `set_boast(profile: &mut UserProfile, checkpoint: Option<address>, ctx: &mut TxContext)`
Sets or clears boast location.
- **Events**: `BoastSet { owner, checkpoint }`

### `add_walrus_item(profile: &mut UserProfile, cid_or_id: String, kind: u8, note: String, ctx: &mut TxContext)`
Bookmarks Walrus content.
- **Events**: `WalrusItemAdded { owner, cid_or_id, kind }`

### `remove_walrus_item(profile: &mut UserProfile, cid_or_id: String, ctx: &mut TxContext)`
Removes bookmarked content.
- **Events**: `WalrusItemRemoved { owner, cid_or_id }`

## Package Functions

### `append_letters(profile: &mut UserProfile, letters: String, _ctx: &mut TxContext)`
Adds letters to inventory (called by checkpoint module).
- **Events**: `LettersAppended { owner, letters }`

### `can_consume(profile: &UserProfile, need: String): bool`
Checks if user has enough letters.

### `consume_letters(profile: &mut UserProfile, need: String, _ctx: &mut TxContext)`
Atomically consumes letters from inventory.
- **Events**: `LettersConsumed { owner, letters }`
- **Errors**: `E_INVENTORY_SHORTAGE`

### `record_visit(profile: &mut UserProfile, checkpoint_addr: address, now_epoch: u64, _ctx: &mut TxContext)`
Records checkpoint visit.
- **Events**: `VisitRecorded { owner, checkpoint, count, last_epoch }`

## Letter System

### Normalization Rules
- Convert to uppercase (a-z → A-Z)
- Ignore spaces, tabs, newlines
- Count only valid characters

### Consumption Policy
- Atomic all-or-nothing operations
- Multiset subtraction algorithm
- Case-insensitive matching

## Events

- `ProfileCreated { owner }`
- `VisitRecorded { owner, checkpoint, count, last_epoch }`
- `LettersAppended { owner, letters }`
- `LettersConsumed { owner, letters }`
- `BoastSet { owner, checkpoint }`
- `WalrusItemAdded { owner, cid_or_id, kind }`
- `WalrusItemRemoved { owner, cid_or_id }`

## Error Codes

- `E_WALRUS_ITEM_NOT_FOUND = 2`
- `E_INVENTORY_SHORTAGE = 3`

## Getter Functions

- `letter_bank(profile: &UserProfile): &String`
- `visit_count_total(profile: &UserProfile): u64`
- `boast_checkpoint(profile: &UserProfile): &Option<address>`