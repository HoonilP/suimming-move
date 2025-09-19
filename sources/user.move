#[allow(duplicate_alias)]
module suimming_move::user {
    use std::string::String;
    use std::option::Option;

    use sui::object::{UID, uid_to_address};
    use sui::tx_context::{TxContext, sender, epoch};
    use sui::dynamic_field as df;
    use sui::event;
    use sui::transfer;

    // Error constants
    const E_WALRUS_ITEM_NOT_FOUND: u64 = 2;
    const E_INVENTORY_SHORTAGE: u64 = 3;

    // Note: Using public(package) visibility instead of friend declarations

    // Core data structures
    public struct UserProfile has key, store {
        id: UID,
        created_epoch: u64,
        display_name: Option<String>,
        bio: Option<String>,
        letter_bank: String,
        visit_count_total: u64,
        visits: UID,
        boast_checkpoint: Option<address>,
        walrus_items: UID,
    }

    public struct VisitStat has store {
        count: u64,
        last_epoch: u64,
    }

    public struct WalrusItem has store, drop {
        cid_or_id: String,
        kind: u8, // 0 raw text, 1 rendered image, 2 other
        note: String,
        created_epoch: u64,
    }

    public struct LetterCount has store, drop {
        letter: u8,
        count: u64,
    }

    // Events
    public struct ProfileCreated has copy, drop {
        owner: address,
    }

    public struct VisitRecorded has copy, drop {
        owner: address,
        checkpoint: address,
        count: u64,
        last_epoch: u64,
    }

    public struct LettersAppended has copy, drop {
        owner: address,
        letters: String,
    }

    public struct LettersConsumed has copy, drop {
        owner: address,
        letters: String,
    }

    public struct BoastSet has copy, drop {
        owner: address,
        checkpoint: Option<address>,
    }

    public struct WalrusItemAdded has copy, drop {
        owner: address,
        cid_or_id: String,
        kind: u8,
    }

    public struct WalrusItemRemoved has copy, drop {
        owner: address,
        cid_or_id: String,
    }

    // Public entry functions
    #[allow(lint(self_transfer))]
    public fun create_profile(ctx: &mut TxContext) {
        let sender = sender(ctx);

        // Check if profile already exists would require a registry pattern
        // For simplicity, we'll allow multiple profiles per address for now
        // In production, you'd want to maintain a registry

        let profile = UserProfile {
            id: sui::object::new(ctx),
            created_epoch: epoch(ctx),
            display_name: std::option::none(),
            bio: std::option::none(),
            letter_bank: std::string::utf8(b""),
            visit_count_total: 0,
            visits: sui::object::new(ctx),
            boast_checkpoint: std::option::none(),
            walrus_items: sui::object::new(ctx),
        };

        event::emit(ProfileCreated { owner: sender });

        transfer::public_transfer(profile, sender);
    }

    public fun update_profile(
        profile: &mut UserProfile,
        display_name: Option<String>,
        bio: Option<String>,
        _ctx: &mut TxContext
    ) {
        if (std::option::is_some(&display_name)) {
            profile.display_name = display_name;
        };

        if (std::option::is_some(&bio)) {
            profile.bio = bio;
        };
    }

    public fun set_boast(
        profile: &mut UserProfile,
        checkpoint: Option<address>,
        ctx: &mut TxContext
    ) {
        profile.boast_checkpoint = checkpoint;

        event::emit(BoastSet {
            owner: sender(ctx),
            checkpoint,
        });
    }

    public fun add_walrus_item(
        profile: &mut UserProfile,
        cid_or_id: String,
        kind: u8,
        note: String,
        ctx: &mut TxContext
    ) {
        let item = WalrusItem {
            cid_or_id,
            kind,
            note,
            created_epoch: epoch(ctx),
        };

        let key = *std::string::as_bytes(&cid_or_id);
        df::add(&mut profile.walrus_items, key, item);

        event::emit(WalrusItemAdded {
            owner: sender(ctx),
            cid_or_id,
            kind,
        });
    }

    public fun remove_walrus_item(
        profile: &mut UserProfile,
        cid_or_id: String,
        ctx: &mut TxContext
    ) {
        let key = *std::string::as_bytes(&cid_or_id);
        assert!(df::exists_(&profile.walrus_items, key), E_WALRUS_ITEM_NOT_FOUND);

        let _item: WalrusItem = df::remove(&mut profile.walrus_items, key);

        event::emit(WalrusItemRemoved {
            owner: sender(ctx),
            cid_or_id,
        });
    }

    // Package functions (only callable by modules in this package)
    public(package) fun append_letters(
        profile: &mut UserProfile,
        letters: String,
        _ctx: &mut TxContext
    ) {
        std::string::append(&mut profile.letter_bank, letters);

        event::emit(LettersAppended {
            owner: uid_to_address(&profile.id),
            letters,
        });
    }

    public(package) fun can_consume(profile: &UserProfile, need: String): bool {
        can_consume_letters(&profile.letter_bank, need)
    }

    public(package) fun consume_letters(
        profile: &mut UserProfile,
        need: String,
        _ctx: &mut TxContext
    ) {
        let normalized_need = normalize_letters(need);
        assert!(can_consume_letters(&profile.letter_bank, normalized_need), E_INVENTORY_SHORTAGE);

        profile.letter_bank = subtract_letters(profile.letter_bank, normalized_need);

        event::emit(LettersConsumed {
            owner: uid_to_address(&profile.id),
            letters: normalized_need,
        });
    }

    public(package) fun record_visit(
        profile: &mut UserProfile,
        checkpoint_addr: address,
        now_epoch: u64,
        _ctx: &mut TxContext
    ) {
        profile.visit_count_total = profile.visit_count_total + 1;

        // Update or create visit stat for this checkpoint
        if (df::exists_(&profile.visits, checkpoint_addr)) {
            let visit_stat: &mut VisitStat = df::borrow_mut(&mut profile.visits, checkpoint_addr);
            visit_stat.count = visit_stat.count + 1;
            visit_stat.last_epoch = now_epoch;
        } else {
            let visit_stat = VisitStat {
                count: 1,
                last_epoch: now_epoch,
            };
            df::add(&mut profile.visits, checkpoint_addr, visit_stat);
        };

        let visit_stat: &VisitStat = df::borrow(&profile.visits, checkpoint_addr);
        event::emit(VisitRecorded {
            owner: uid_to_address(&profile.id),
            checkpoint: checkpoint_addr,
            count: visit_stat.count,
            last_epoch: visit_stat.last_epoch,
        });
    }

    // Helper functions for letter manipulation
    fun normalize_letters(letters: String): String {
        // Convert to uppercase and remove whitespace
        let bytes = std::string::as_bytes(&letters);
        let mut normalized_bytes = std::vector::empty<u8>();

        let mut i = 0;
        while (i < std::vector::length(bytes)) {
            let mut byte = *std::vector::borrow(bytes, i);

            // Skip spaces, tabs, newlines
            if (byte != 32 && byte != 9 && byte != 10 && byte != 13) {
                // Convert lowercase to uppercase (a-z -> A-Z)
                if (byte >= 97 && byte <= 122) {
                    byte = byte - 32;
                };
                std::vector::push_back(&mut normalized_bytes, byte);
            };

            i = i + 1;
        };

        std::string::utf8(normalized_bytes)
    }

    fun can_consume_letters(inventory: &String, need: String): bool {
        let normalized_need = normalize_letters(need);
        let inventory_counts = count_letters(*inventory);
        let need_counts = count_letters(normalized_need);

        // Check if inventory has enough of each letter type
        let mut i = 0;
        while (i < std::vector::length(&need_counts)) {
            let need_count = std::vector::borrow(&need_counts, i);
            let available_count = get_letter_count(&inventory_counts, need_count.letter);

            if (available_count < need_count.count) {
                return false
            };

            i = i + 1;
        };

        true
    }

    fun subtract_letters(inventory: String, need: String): String {
        let normalized_need = normalize_letters(need);
        let mut inventory_counts = count_letters(inventory);
        let need_counts = count_letters(normalized_need);

        // Subtract needed letters from inventory counts
        let mut i = 0;
        while (i < std::vector::length(&need_counts)) {
            let need_count = std::vector::borrow(&need_counts, i);
            subtract_letter_count(&mut inventory_counts, need_count.letter, need_count.count);
            i = i + 1;
        };

        // Rebuild string from remaining counts
        counts_to_string(inventory_counts)
    }

    fun count_letters(letters: String): vector<LetterCount> {
        let bytes = std::string::as_bytes(&letters);
        let mut counts = std::vector::empty<LetterCount>();

        let mut i = 0;
        while (i < std::vector::length(bytes)) {
            let letter = *std::vector::borrow(bytes, i);

            // Find or create entry for this letter
            let mut j = 0;
            let mut found = false;
            while (j < std::vector::length(&counts)) {
                let letter_count = std::vector::borrow_mut(&mut counts, j);
                if (letter_count.letter == letter) {
                    letter_count.count = letter_count.count + 1;
                    found = true;
                    break
                };
                j = j + 1;
            };

            if (!found) {
                std::vector::push_back(&mut counts, LetterCount { letter, count: 1 });
            };

            i = i + 1;
        };

        counts
    }

    fun get_letter_count(counts: &vector<LetterCount>, letter: u8): u64 {
        let mut i = 0;
        while (i < std::vector::length(counts)) {
            let letter_count = std::vector::borrow(counts, i);
            if (letter_count.letter == letter) {
                return letter_count.count
            };
            i = i + 1;
        };
        0
    }

    fun subtract_letter_count(counts: &mut vector<LetterCount>, letter: u8, amount: u64) {
        let mut i = 0;
        while (i < std::vector::length(counts)) {
            let letter_count = std::vector::borrow_mut(counts, i);
            if (letter_count.letter == letter) {
                letter_count.count = letter_count.count - amount;
                return
            };
            i = i + 1;
        };
    }

    fun counts_to_string(counts: vector<LetterCount>): String {
        let mut result_bytes = std::vector::empty<u8>();

        let mut i = 0;
        while (i < std::vector::length(&counts)) {
            let letter_count = std::vector::borrow(&counts, i);

            let mut j = 0;
            while (j < letter_count.count) {
                std::vector::push_back(&mut result_bytes, letter_count.letter);
                j = j + 1;
            };

            i = i + 1;
        };

        std::string::utf8(result_bytes)
    }

    // Getter functions
    public fun letter_bank(profile: &UserProfile): &String {
        &profile.letter_bank
    }

    public fun visit_count_total(profile: &UserProfile): u64 {
        profile.visit_count_total
    }

    public fun boast_checkpoint(profile: &UserProfile): &Option<address> {
        &profile.boast_checkpoint
    }
}