#[allow(duplicate_alias)]
module suimming_move::checkpoint {
    use std::string::String;

    use sui::object::{UID, uid_to_address};
    use sui::tx_context::{TxContext, sender, epoch};
    use sui::dynamic_field as df;
    use sui::event;
    use sui::transfer;
    use sui::random::{Random, new_generator, generate_u8};

    use suimming_move::user::{Self as user, UserProfile};

    // Error constants
    const E_NOT_ACTIVE: u64 = 1;
    const E_DUP_CLAIM_IN_EPOCH: u64 = 2;

    // Core data structures
    public struct Checkpoint has key, store {
        id: UID,
        active: bool,
        label: String,
        meta_walrus_id: String,
        seal_ref: String,
        visitors: UID,
        boasters: UID,
    }

    public struct VisitLog has store, drop {
        claim_count: u64,
        last_claim_epoch: u64,
    }

    public struct BoastInfo has store, drop {
        sentence_id: address,
        since_epoch: u64,
    }

    public struct AdminCap has key, store {
        id: UID,
    }

    // Events
    public struct CheckpointCreated has copy, drop {
        checkpoint: address,
        label: String,
    }

    public struct CheckpointToggled has copy, drop {
        checkpoint: address,
        active: bool,
    }

    public struct LettersClaimed has copy, drop {
        owner: address,
        checkpoint: address,
        letters: String,
    }

    public struct Boasted has copy, drop {
        owner: address,
        checkpoint: address,
        sentence_id: address,
    }

    public struct Unboasted has copy, drop {
        owner: address,
        checkpoint: address,
    }

    // Public entry functions
    #[allow(lint(self_transfer))]
    public fun create_admin_cap(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: sui::object::new(ctx),
        };

        transfer::public_transfer(admin_cap, sender(ctx));
    }

    #[allow(lint(self_transfer))]
    public fun create_checkpoint(
        _admin: &AdminCap,
        label: String,
        meta_walrus_id: String,
        seal_ref: String,
        ctx: &mut TxContext
    ) {
        let checkpoint = Checkpoint {
            id: sui::object::new(ctx),
            active: true,
            label,
            meta_walrus_id,
            seal_ref,
            visitors: sui::object::new(ctx),
            boasters: sui::object::new(ctx),
        };

        event::emit(CheckpointCreated {
            checkpoint: uid_to_address(&checkpoint.id),
            label: checkpoint.label,
        });

        transfer::share_object(checkpoint);
    }

    public fun toggle_checkpoint(
        _admin: &AdminCap,
        checkpoint: &mut Checkpoint,
        on: bool,
        _ctx: &mut TxContext
    ) {
        checkpoint.active = on;

        event::emit(CheckpointToggled {
            checkpoint: uid_to_address(&checkpoint.id),
            active: on,
        });
    }

    #[allow(lint(public_random))]
    public fun claim_letters(
        checkpoint: &mut Checkpoint,
        user_profile: &mut UserProfile,
        r: &Random,
        ctx: &mut TxContext
    ) {
        assert!(checkpoint.active, E_NOT_ACTIVE);

        let current_epoch = epoch(ctx);
        let user_addr = sender(ctx);
        let checkpoint_addr = uid_to_address(&checkpoint.id);

        // Check for duplicate claim in same epoch
        if (df::exists_(&checkpoint.visitors, user_addr)) {
            let visit_log: &VisitLog = df::borrow(&checkpoint.visitors, user_addr);
            assert!(visit_log.last_claim_epoch != current_epoch, E_DUP_CLAIM_IN_EPOCH);
        };

        // Generate random letter (A-Z)
        let mut generator = new_generator(r, ctx);
        let random_value = generate_u8(&mut generator);
        let random_letter_code = 65 + (random_value % 26); // ASCII A-Z
        let letter_bytes = std::vector::singleton(random_letter_code);
        let letters = std::string::utf8(letter_bytes);

        // Update visit log
        if (df::exists_(&checkpoint.visitors, user_addr)) {
            let visit_log: &mut VisitLog = df::borrow_mut(&mut checkpoint.visitors, user_addr);
            visit_log.claim_count = visit_log.claim_count + 1;
            visit_log.last_claim_epoch = current_epoch;
        } else {
            let visit_log = VisitLog {
                claim_count: 1,
                last_claim_epoch: current_epoch,
            };
            df::add(&mut checkpoint.visitors, user_addr, visit_log);
        };

        // Append letters to user profile
        user::append_letters(user_profile, letters, ctx);

        // Record visit in user profile
        user::record_visit(user_profile, checkpoint_addr, current_epoch, ctx);

        event::emit(LettersClaimed {
            owner: user_addr,
            checkpoint: checkpoint_addr,
            letters,
        });
    }

    public fun boast_here(
        checkpoint: &mut Checkpoint,
        user_profile: &mut UserProfile,
        sentence_id: address,
        ctx: &mut TxContext
    ) {
        let user_addr = sender(ctx);
        let checkpoint_addr = uid_to_address(&checkpoint.id);
        let current_epoch = epoch(ctx);

        // Note: In a full implementation, we'd verify sentence ownership
        // For now we trust the caller owns the sentence they're referencing

        // Update boast info
        let boast_info = BoastInfo {
            sentence_id,
            since_epoch: current_epoch,
        };

        // Add or update boast mapping
        if (df::exists_(&checkpoint.boasters, user_addr)) {
            let _existing_boast: BoastInfo = df::remove(&mut checkpoint.boasters, user_addr);
            df::add(&mut checkpoint.boasters, user_addr, boast_info);
        } else {
            df::add(&mut checkpoint.boasters, user_addr, boast_info);
        };

        // Update user profile boast checkpoint
        user::set_boast(user_profile, std::option::some(checkpoint_addr), ctx);

        event::emit(Boasted {
            owner: user_addr,
            checkpoint: checkpoint_addr,
            sentence_id,
        });
    }

    public fun unboast_here(
        checkpoint: &mut Checkpoint,
        user_profile: &mut UserProfile,
        ctx: &mut TxContext
    ) {
        let user_addr = sender(ctx);
        let checkpoint_addr = uid_to_address(&checkpoint.id);

        // Remove boast mapping if it exists
        if (df::exists_(&checkpoint.boasters, user_addr)) {
            let _boast_info: BoastInfo = df::remove(&mut checkpoint.boasters, user_addr);
        };

        // Clear user profile boast checkpoint
        user::set_boast(user_profile, std::option::none(), ctx);

        event::emit(Unboasted {
            owner: user_addr,
            checkpoint: checkpoint_addr,
        });
    }

    // Getter functions
    public fun active(checkpoint: &Checkpoint): bool {
        checkpoint.active
    }

    public fun label(checkpoint: &Checkpoint): &String {
        &checkpoint.label
    }

    public fun meta_walrus_id(checkpoint: &Checkpoint): &String {
        &checkpoint.meta_walrus_id
    }

    public fun seal_ref(checkpoint: &Checkpoint): &String {
        &checkpoint.seal_ref
    }
}