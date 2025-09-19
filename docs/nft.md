# NFT Module Documentation

## Overview
The `nft.move` module handles Sentence NFT creation and trading by consuming letters from user inventories.

## Data Structures

### Sentence
```move
public struct Sentence has key, store {
    id: UID,
    text: String,              // Caption/title for display
    walrus_cid: String,        // Canvas-rendered image CID
    created_epoch: u64,        // Creation timestamp
    letters_used: u64,         // Number of letters consumed
}
```

## Public Functions

### NFT Creation

#### `mint_sentence_from_profile(user_profile: &mut UserProfile, consume: String, text: String, walrus_cid: String, ctx: &mut TxContext)`
Creates Sentence NFT by consuming letters.

**Process:**
1. Validates text and walrus_cid are non-empty
2. Checks letter availability via `user::can_consume()`
3. Counts required letters for transparency
4. Consumes letters via `user::consume_letters()`
5. Mints NFT and transfers to sender

**Parameters:**
- `user_profile` - User's profile with letter inventory
- `consume` - Letters to consume (normalized)
- `text` - Display text for NFT
- `walrus_cid` - Walrus content identifier for image

**Events:** `SentenceMinted { owner, sentence_id, letters_used }`

**Errors:**
- `E_TEXT_OR_CID_EMPTY` - Empty text or CID
- `E_INVENTORY_SHORTAGE` - Insufficient letters

### NFT Transfer

#### `transfer_sentence(sentence: Sentence, to: address, ctx: &mut TxContext)`
Direct P2P transfer (gifting).
- **Events**: `SentenceTransferred { from, to, sentence_id }`

## Letter Counting

### `count_required_letters(consume: String): u64`
Counts letters needed for minting.

**Rules:**
- Ignores spaces (ASCII 32)
- Ignores tabs (ASCII 9)
- Ignores newlines (ASCII 10, 13)
- Counts all other characters

**Example:**
```
Input: "HELLO WORLD!"
Output: 11 (space ignored)
```

## Integration

### User Module Integration
- `user::can_consume()` - Checks availability
- `user::consume_letters()` - Atomic consumption
- Maintains counting consistency

### Marketplace Integration
- Full `key + store` capabilities
- Sui Kiosk compatibility
- Standard object ownership
- Transfer policy support

### Off-chain Integration
- **Rendering**: Client Canvas before minting
- **Storage**: Walrus for images
- **Discovery**: Event indexing for galleries

## Usage Patterns

### Basic Creation Flow
1. User collects letters at checkpoints
2. Client renders artwork on Canvas
3. Client uploads to Walrus, gets CID
4. Call `mint_sentence_from_profile()`
5. Letters consumed, NFT minted

### Trading
- **Gifting**: Use `transfer_sentence()`
- **Selling**: Use Sui Kiosk framework
- **Marketplace**: Standard Sui integration

## Events

### SentenceMinted
```move
public struct SentenceMinted has copy, drop {
    owner: address,
    sentence_id: address,
    letters_used: u64,
}
```

### SentenceTransferred
```move
public struct SentenceTransferred has copy, drop {
    from: address,
    to: address,
    sentence_id: address,
}
```

## Error Codes

- `E_TEXT_OR_CID_EMPTY = 0` - Text or Walrus CID is empty
- `E_INVENTORY_SHORTAGE = 1` - Insufficient letters (from user module)

## Getter Functions

- `text(sentence: &Sentence): &String`
- `walrus_cid(sentence: &Sentence): &String`
- `created_epoch(sentence: &Sentence): u64`
- `letters_used(sentence: &Sentence): u64`

## Security Features

### Input Validation
- Non-empty text and CID requirements
- Letter availability verification
- Atomic consumption operations

### Economic Security
- Letter consumption creates scarcity
- Immutable NFT content
- Transparent letter usage tracking

### Ownership Model
- Standard Sui object semantics
- Transfer events for audit trail
- Marketplace compatibility