# Checkpoint Module Documentation

## Overview
The `checkpoint.move` module manages location-based checkpoints where users claim random letters and showcase NFTs.

## Data Structures

### Checkpoint
```move
public struct Checkpoint has key, store {
    id: UID,
    active: bool,                  // Whether claims/boasts are allowed
    label: String,                 // Human-readable name
    meta_walrus_id: String,        // Walrus CID for metadata
    seal_ref: String,              // Off-chain geofencing policy
    visitors: UID,                 // Dynamic field: address → VisitLog
    boasters: UID,                 // Dynamic field: address → BoastInfo
}
```

### VisitLog
```move
public struct VisitLog has store, drop {
    claim_count: u64,
    last_claim_epoch: u64,
}
```

### BoastInfo
```move
public struct BoastInfo has store, drop {
    sentence_id: address,
    since_epoch: u64,
}
```

### AdminCap
```move
public struct AdminCap has key, store {
    id: UID,
}
```

## Public Functions

### Administrative

#### `create_admin_cap(ctx: &mut TxContext)`
Creates admin capability for checkpoint management.

#### `create_checkpoint(_admin: &AdminCap, label: String, meta_walrus_id: String, seal_ref: String, ctx: &mut TxContext)`
Creates a new checkpoint.
- **Events**: `CheckpointCreated { checkpoint, label }`

#### `toggle_checkpoint(_admin: &AdminCap, checkpoint: &mut Checkpoint, on: bool, _ctx: &mut TxContext)`
Activates/deactivates checkpoint.
- **Events**: `CheckpointToggled { checkpoint, active }`

### Core Game Mechanics

#### `claim_letters(checkpoint: &mut Checkpoint, user_profile: &mut UserProfile, r: &Random, ctx: &mut TxContext)`
Claims random letters at checkpoint.
- **Validation**: Active checkpoint, no duplicate claims per epoch
- **Randomness**: Generates A-Z letters using `sui::random`
- **Events**: `LettersClaimed { owner, checkpoint, letters }`
- **Errors**: `E_NOT_ACTIVE`, `E_DUP_CLAIM_IN_EPOCH`

### Social Features

#### `boast_here(checkpoint: &mut Checkpoint, user_profile: &mut UserProfile, sentence_id: address, ctx: &mut TxContext)`
Showcases Sentence NFT at checkpoint.
- **Events**: `Boasted { owner, checkpoint, sentence_id }`

#### `unboast_here(checkpoint: &mut Checkpoint, user_profile: &mut UserProfile, ctx: &mut TxContext)`
Removes boast from checkpoint.
- **Events**: `Unboasted { owner, checkpoint }`

## Randomness System

### Implementation
```move
let mut generator = new_generator(r, ctx);
let random_value = generate_u8(&mut generator);
let random_letter_code = 65 + (random_value % 26); // ASCII A-Z
```

### Security
- Uses `sui::random` for cryptographic security
- Fresh generator per transaction
- Even distribution across A-Z range
- Protected against manipulation

## Integration

### User Module Calls
- `user::append_letters()` - Adds reward letters
- `user::record_visit()` - Updates visit statistics
- `user::set_boast()` - Manages boast state

### Off-chain Integration
- **Geofencing**: `seal_ref` for location verification
- **Metadata**: `meta_walrus_id` for rich content
- **Events**: Complete audit trail for indexing

## Events

- `CheckpointCreated { checkpoint, label }`
- `CheckpointToggled { checkpoint, active }`
- `LettersClaimed { owner, checkpoint, letters }`
- `Boasted { owner, checkpoint, sentence_id }`
- `Unboasted { owner, checkpoint }`

## Error Codes

- `E_NOT_ACTIVE = 1` - Checkpoint is deactivated
- `E_DUP_CLAIM_IN_EPOCH = 2` - Already claimed this epoch

## Getter Functions

- `active(checkpoint: &Checkpoint): bool`
- `label(checkpoint: &Checkpoint): &String`
- `meta_walrus_id(checkpoint: &Checkpoint): &String`
- `seal_ref(checkpoint: &Checkpoint): &String`

## Anti-abuse Mechanisms

- **Epoch Limits**: One claim per user per checkpoint per epoch
- **Active/Inactive**: Emergency shutdown capability
- **Geofencing**: Off-chain location verification
- **Admin Controls**: Capability-based management