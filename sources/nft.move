#[allow(duplicate_alias)]
module suimming_move::nft {
    use std::string::String;

    use sui::object::{UID, uid_to_address};
    use sui::tx_context::{TxContext, sender, epoch};
    use sui::event;
    use sui::transfer;

    use suimming_move::user::{Self as user, UserProfile};

    // Error constants
    const E_TEXT_OR_CID_EMPTY: u64 = 0;
    const E_INVENTORY_SHORTAGE: u64 = 1;

    // Core data structures
    public struct Sentence has key, store {
        id: UID,
        text: String,
        walrus_cid: String,
        created_epoch: u64,
        letters_used: u64,
    }

    // Events
    public struct SentenceMinted has copy, drop {
        owner: address,
        sentence_id: address,
        letters_used: u64,
    }

    public struct SentenceTransferred has copy, drop {
        from: address,
        to: address,
        sentence_id: address,
    }

    // Public entry functions
    #[allow(lint(self_transfer))]
    public fun mint_sentence_from_profile(
        user_profile: &mut UserProfile,
        consume: String,
        text: String,
        walrus_cid: String,
        ctx: &mut TxContext
    ) {
        // Validate inputs
        assert!(std::string::length(&text) > 0, E_TEXT_OR_CID_EMPTY);
        assert!(std::string::length(&walrus_cid) > 0, E_TEXT_OR_CID_EMPTY);

        // Check if user can consume the required letters
        assert!(user::can_consume(user_profile, consume), E_INVENTORY_SHORTAGE);

        // Count letters needed for this sentence
        let letters_used = count_required_letters(consume);

        // Consume letters from user profile
        user::consume_letters(user_profile, consume, ctx);

        // Create the Sentence NFT
        let sentence = Sentence {
            id: sui::object::new(ctx),
            text,
            walrus_cid,
            created_epoch: epoch(ctx),
            letters_used,
        };

        let owner = sender(ctx);
        let sentence_id = uid_to_address(&sentence.id);

        event::emit(SentenceMinted {
            owner,
            sentence_id,
            letters_used,
        });

        transfer::public_transfer(sentence, owner);
    }

    public fun transfer_sentence(sentence: Sentence, to: address, ctx: &mut TxContext) {
        let from = sender(ctx);
        let sentence_id = uid_to_address(&sentence.id);

        event::emit(SentenceTransferred {
            from,
            to,
            sentence_id,
        });

        transfer::public_transfer(sentence, to);
    }

    // Helper functions
    fun count_required_letters(consume: String): u64 {
        let bytes = std::string::as_bytes(&consume);
        let mut count = 0;

        let mut i = 0;
        while (i < std::vector::length(bytes)) {
            let byte = *std::vector::borrow(bytes, i);

            // Count only letters, ignore spaces, tabs, newlines
            if (byte != 32 && byte != 9 && byte != 10 && byte != 13) {
                count = count + 1;
            };

            i = i + 1;
        };

        count
    }

    // Getter functions
    public fun text(sentence: &Sentence): &String {
        &sentence.text
    }

    public fun walrus_cid(sentence: &Sentence): &String {
        &sentence.walrus_cid
    }

    public fun created_epoch(sentence: &Sentence): u64 {
        sentence.created_epoch
    }

    public fun letters_used(sentence: &Sentence): u64 {
        sentence.letters_used
    }

    public fun get_id(sentence: &Sentence): &UID {
        &sentence.id
    }

    // Display setup (optional, for NFT marketplaces)
    // Note: Display creation would typically be done in a separate init function
    // with proper publisher setup. This is left as a placeholder for future implementation.
}