# Suimming Move Package Documentation

## Overview

Suimming is a location-based collection game built on Sui where players collect letters at physical locations and mint Sentence NFTs. This Move package implements the core on-chain logic following a minimal, production-ready architecture.

## Package Structure

```
suimming-move/
├── sources/
│   ├── user.move          # User profiles and letter inventory
│   ├── checkpoint.move    # Location management and rewards
│   └── nft.move          # Sentence NFT creation and trading
├── docs/
│   ├── README.md         # This file
│   ├── user.md           # User module documentation
│   ├── checkpoint.md     # Checkpoint module documentation
│   └── nft.md           # NFT module documentation
└── Move.toml             # Package configuration
```

## Architecture Principles

### Minimal On-chain State
- Store only essential data: user inventory, visit stats, NFTs
- Heavy content (images, metadata) lives in Walrus
- Events provide complete audit trail for indexers

### Module Boundaries
- **user**: Profile management, letter inventory, visit tracking
- **checkpoint**: Location lifecycle, randomized rewards, social features
- **nft**: Sentence NFT minting and transfers

### Security Model
- Package visibility for controlled inter-module access
- Atomic letter consumption prevents partial updates
- Event-driven design for transparency and indexability

## Core Game Loop

1. **Profile Creation**: Users create profiles to track inventory and stats
2. **Location Visits**: Players visit checkpoints to claim random letters
3. **Letter Collection**: Randomized A-Z rewards with epoch-based limits
4. **NFT Creation**: Consume letters to mint Sentence NFTs with custom artwork
5. **Social Interaction**: Boast NFTs at locations for discovery
6. **Trading**: P2P transfers and marketplace integration via Sui Kiosk

## Module Integration

### Package Functions
Modules communicate through `public(package)` functions:

```
checkpoint -> user: append_letters(), record_visit(), set_boast()
nft -> user: can_consume(), consume_letters()
```

### Off-chain Integration
- **Geofencing**: Seal policy enforcement (mobile + backend)
- **Rendering**: JavaScript Canvas for NFT artwork
- **Storage**: Walrus for decentralized content
- **Discovery**: Event indexing for maps and galleries

## Key Features

### Letter System
- Uppercase normalization for consistency
- Whitespace-aware consumption (spaces don't count)
- Atomic multiset operations
- Deterministic counting across all operations

### Randomness
- Cryptographically secure via `sui::random`
- A-Z letter generation (ASCII 65-90)
- Per-epoch claim limits prevent abuse
- Gas-efficient single letter rewards

### NFT Economics
- Letters create scarcity and value
- Transparent consumption tracking
- Immutable content for provenance
- Standard Sui object model for trading

### Social Features
- Checkpoint boasting for discovery
- Visit statistics and leaderboards
- Event-driven feeds and notifications
- Community-driven content creation

## Deployment Guide

### Prerequisites
- Sui CLI installed and configured
- Access to Sui testnet/mainnet
- Wallet with sufficient SUI for deployment

### Steps
1. **Deploy Package**
   ```bash
   sui move build
   sui move publish
   ```

2. **Initialize Admin**
   ```bash
   sui move call --function create_admin_cap --module checkpoint
   ```

3. **Create Checkpoints**
   ```bash
   sui move call --function create_checkpoint --module checkpoint \
     --args $ADMIN_CAP "Location Name" "walrus_meta_id" "seal_policy_ref"
   ```

4. **Configure Off-chain**
   - Set up geofencing policies in Seal
   - Deploy indexer for event processing
   - Configure Walrus gateway for content delivery

## API Reference

### Quick Start Examples

#### Create User Profile
```bash
sui move call --function create_profile --module user
```

#### Claim Letters at Checkpoint
```bash
sui move call --function claim_letters --module checkpoint \
  --args $CHECKPOINT $USER_PROFILE $RANDOM_OBJECT
```

#### Mint Sentence NFT
```bash
sui move call --function mint_sentence_from_profile --module nft \
  --args $USER_PROFILE "HELLO" "Hello World!" "walrus_image_cid"
```

### Module Documentation
- [User Module](user.md) - Profiles, inventory, visits
- [Checkpoint Module](checkpoint.md) - Locations, rewards, boasting
- [NFT Module](nft.md) - Sentence creation and trading

## Event Schema

All state changes emit events for off-chain indexing:

### User Events
- `ProfileCreated`, `VisitRecorded`, `LettersAppended`, `LettersConsumed`, `BoastSet`

### Checkpoint Events
- `CheckpointCreated`, `CheckpointToggled`, `LettersClaimed`, `Boasted`, `Unboasted`

### NFT Events
- `SentenceMinted`, `SentenceTransferred`

## Security Considerations

### Access Control
- Admin capabilities for checkpoint management
- Package visibility for inventory mutations
- Transaction sender validation for all user operations

### Economic Security
- Epoch-based claim limits prevent farming
- Atomic letter consumption ensures consistency
- Transparent event emission for auditability

### Randomness Security
- Sui's secure random number generator
- Fresh entropy per transaction
- Public visibility acceptable for equal probability

## Testing Strategy

### Unit Tests
- Letter normalization and counting
- Inventory consumption edge cases
- Random letter generation distribution
- Event emission verification

### Integration Tests
- End-to-end user journey flows
- Cross-module state consistency
- Error condition handling
- Gas optimization validation

### Load Testing
- High-volume checkpoint claiming
- Concurrent user interactions
- Dynamic field scalability
- Event indexer performance

## Monitoring and Maintenance

### Key Metrics
- User registration rates
- Letter claim frequency
- NFT minting volume
- Checkpoint activity distribution

### Operational Tasks
- Monitor checkpoint health
- Update Walrus metadata
- Manage admin capabilities
- Coordinate upgrades

### Upgrade Strategy
- Immutable objects for user data
- Versioned events for compatibility
- Graceful migration procedures
- Backward compatibility maintenance

## Contributing

### Development Setup
1. Install Sui toolchain
2. Clone repository
3. Run `sui move build` to verify
4. Check `sui move test` for validation

### Code Standards
- Comprehensive documentation
- Event emission for all state changes
- Error handling for edge cases
- Gas optimization considerations

### Pull Request Process
1. Add/update relevant documentation
2. Include unit tests for new features
3. Verify no compilation warnings
4. Update event schemas if needed