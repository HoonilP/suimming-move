#[allow(duplicate_alias)]
module suimming_move::marketplace {
    use std::string::String;
    use sui::object::{UID, uid_to_address};
    use sui::tx_context::{TxContext, sender, epoch};
    use sui::event;
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};

    use suimming_move::nft::{Self as nft, Sentence};

    // Error constants
    const E_NOT_OWNER: u64 = 0;
    const E_ALREADY_LISTED: u64 = 1;
    const E_NOT_LISTED: u64 = 2;
    const E_INSUFFICIENT_PAYMENT: u64 = 3;
    const E_INVALID_PRICE: u64 = 4;

    // Core data structures
    public struct Marketplace has key {
        id: UID,
        listings: Table<address, Listing>,
        fee_percentage: u64, // Fee in basis points (e.g., 250 = 2.5%)
        fee_balance: Balance<SUI>,
    }

    public struct Listing has store, drop {
        nft_id: address,
        seller: address,
        price: u64, // Price in MIST
        text: String,
        walrus_cid: String,
        listed_epoch: u64,
    }

    // Admin capability for marketplace management
    public struct MarketplaceAdminCap has key, store {
        id: UID,
    }

    // Events
    public struct NFTListed has copy, drop {
        marketplace_id: address,
        nft_id: address,
        seller: address,
        price: u64,
        listed_epoch: u64,
    }

    public struct NFTDelisted has copy, drop {
        marketplace_id: address,
        nft_id: address,
        seller: address,
    }

    public struct NFTPurchased has copy, drop {
        marketplace_id: address,
        nft_id: address,
        seller: address,
        buyer: address,
        price: u64,
        fee_amount: u64,
    }

    public struct MarketplaceCreated has copy, drop {
        marketplace_id: address,
        admin: address,
    }

    // Initialize marketplace - called once during deployment
    fun init(ctx: &mut TxContext) {
        let marketplace = Marketplace {
            id: sui::object::new(ctx),
            listings: table::new(ctx),
            fee_percentage: 250, // 2.5% default fee
            fee_balance: balance::zero(),
        };

        let admin_cap = MarketplaceAdminCap {
            id: sui::object::new(ctx),
        };

        let marketplace_id = uid_to_address(&marketplace.id);
        let admin = sender(ctx);

        event::emit(MarketplaceCreated {
            marketplace_id,
            admin,
        });

        transfer::share_object(marketplace);
        transfer::public_transfer(admin_cap, admin);
    }

    // List an NFT for sale
    public fun list_nft(
        marketplace: &mut Marketplace,
        nft: Sentence,
        price: u64,
        ctx: &mut TxContext
    ) {
        assert!(price > 0, E_INVALID_PRICE);

        let nft_id = uid_to_address(nft::get_id(&nft));
        let seller = sender(ctx);

        assert!(!table::contains(&marketplace.listings, nft_id), E_ALREADY_LISTED);

        let listing = Listing {
            nft_id,
            seller,
            price,
            text: *nft::text(&nft),
            walrus_cid: *nft::walrus_cid(&nft),
            listed_epoch: epoch(ctx),
        };

        table::add(&mut marketplace.listings, nft_id, listing);

        event::emit(NFTListed {
            marketplace_id: uid_to_address(&marketplace.id),
            nft_id,
            seller,
            price,
            listed_epoch: epoch(ctx),
        });

        // Transfer NFT to marketplace for escrow
        transfer::public_transfer(nft, uid_to_address(&marketplace.id));
    }

    // Delist an NFT (only by seller)
    public fun delist_nft(
        marketplace: &mut Marketplace,
        nft: Sentence,
        nft_id: address,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&marketplace.listings, nft_id), E_NOT_LISTED);

        let listing = table::remove(&mut marketplace.listings, nft_id);
        assert!(listing.seller == sender(ctx), E_NOT_OWNER);

        event::emit(NFTDelisted {
            marketplace_id: uid_to_address(&marketplace.id),
            nft_id,
            seller: listing.seller,
        });

        // Return NFT to seller
        transfer::public_transfer(nft, listing.seller);
    }

    // Purchase an NFT
    #[allow(lint(self_transfer))]
    public fun purchase_nft(
        marketplace: &mut Marketplace,
        nft: Sentence,
        mut payment: Coin<SUI>,
        nft_id: address,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&marketplace.listings, nft_id), E_NOT_LISTED);

        let listing = table::remove(&mut marketplace.listings, nft_id);
        let buyer = sender(ctx);

        assert!(coin::value(&payment) >= listing.price, E_INSUFFICIENT_PAYMENT);

        // Calculate marketplace fee
        let fee_amount = (listing.price * marketplace.fee_percentage) / 10000;
        let seller_amount = listing.price - fee_amount;

        // Split payment
        let fee_coin = coin::split(&mut payment, fee_amount, ctx);
        let seller_coin = coin::split(&mut payment, seller_amount, ctx);

        // Add fee to marketplace balance
        balance::join(&mut marketplace.fee_balance, coin::into_balance(fee_coin));

        // Pay seller
        transfer::public_transfer(seller_coin, listing.seller);

        // Return any excess payment to buyer
        if (coin::value(&payment) > 0) {
            transfer::public_transfer(payment, buyer);
        } else {
            coin::destroy_zero(payment);
        };

        event::emit(NFTPurchased {
            marketplace_id: uid_to_address(&marketplace.id),
            nft_id,
            seller: listing.seller,
            buyer,
            price: listing.price,
            fee_amount,
        });

        // Transfer NFT to buyer
        transfer::public_transfer(nft, buyer);
    }

    // Admin function to update fee percentage
    public fun update_fee_percentage(
        _admin_cap: &MarketplaceAdminCap,
        marketplace: &mut Marketplace,
        new_fee_percentage: u64,
    ) {
        assert!(new_fee_percentage <= 1000, E_INVALID_PRICE); // Max 10% fee
        marketplace.fee_percentage = new_fee_percentage;
    }

    // Admin function to withdraw fees
    public fun withdraw_fees(
        _admin_cap: &MarketplaceAdminCap,
        marketplace: &mut Marketplace,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let fee_amount = balance::value(&marketplace.fee_balance);
        let fee_balance = balance::split(&mut marketplace.fee_balance, fee_amount);
        coin::from_balance(fee_balance, ctx)
    }

    // Getter functions
    public fun get_listing(marketplace: &Marketplace, nft_id: address): &Listing {
        table::borrow(&marketplace.listings, nft_id)
    }

    public fun is_listed(marketplace: &Marketplace, nft_id: address): bool {
        table::contains(&marketplace.listings, nft_id)
    }

    public fun listing_price(listing: &Listing): u64 {
        listing.price
    }

    public fun listing_seller(listing: &Listing): address {
        listing.seller
    }

    public fun listing_text(listing: &Listing): &String {
        &listing.text
    }

    public fun listing_walrus_cid(listing: &Listing): &String {
        &listing.walrus_cid
    }

    public fun listing_epoch(listing: &Listing): u64 {
        listing.listed_epoch
    }

    public fun marketplace_fee_percentage(marketplace: &Marketplace): u64 {
        marketplace.fee_percentage
    }

    public fun marketplace_fee_balance(marketplace: &Marketplace): u64 {
        balance::value(&marketplace.fee_balance)
    }

    // Get all listing IDs (for frontend to iterate)
    #[allow(unused_variable)]
    public fun get_all_listing_ids(_marketplace: &Marketplace): vector<address> {
        // Note: This is a simplified version. In practice, you might want to implement
        // pagination or use dynamic fields for better performance with large datasets
        let ids = vector::empty<address>();
        // For now, this would need to be implemented using table iteration
        // which might require additional helper functions
        ids
    }
}