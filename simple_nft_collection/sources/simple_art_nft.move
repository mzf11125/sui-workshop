module simple_nft_collection::simple_art_nft {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::vec_map::{Self, VecMap};
    use sui::dynamic_field as df;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::display;
    use sui::package;
    use std::string::{Self, String, utf8};

    // === Error Codes ===
    const ENotAuthorized: u64 = 1;
    const EMaxSupplyReached: u64 = 2;
    const EInsufficientPayment: u64 = 3;
    const EMintNotActive: u64 = 4;

    // === One-Time Witness ===
    public struct SIMPLE_ART_NFT has drop {}

    // === Core Structs ===

    /// Simple NFT with essential metadata
    public struct SimpleNFT has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: String,
        creator: address,
        attributes: VecMap<String, String>,
    }

    /// Collection with time-based minting
    public struct Collection has key {
        id: UID,
        name: String,
        description: String,
        creator: address,
        total_supply: u64,
        max_supply: u64,
        mint_price: u64,
        mint_start_time: u64,
        mint_end_time: u64,
        is_active: bool,
    }

    /// Admin capability
    public struct AdminCap has key, store {
        id: UID,
        collection_id: ID,
    }

    // === Events ===

    public struct NFTMinted has copy, drop {
        nft_id: ID,
        name: String,
        recipient: address,
        collection_id: ID,
        edition_number: u64,
    }

    public struct CollectionCreated has copy, drop {
        collection_id: ID,
        name: String,
        creator: address,
        max_supply: u64,
    }

    // === Init Function ===

    fun init(witness: SIMPLE_ART_NFT, ctx: &mut TxContext) {
        // Create display template for wallets and marketplaces
        let keys = vector[
            utf8(b"name"),
            utf8(b"description"),
            utf8(b"image_url"),
            utf8(b"creator"),
            utf8(b"project_url"),
        ];

        let values = vector[
            utf8(b"{name}"),
            utf8(b"{description}"),
            utf8(b"{image_url}"),
            utf8(b"{creator}"),
            utf8(b"https://myproject.com"),
        ];

        let publisher = package::claim(witness, ctx);
        let mut display = display::new_with_fields<SimpleNFT>(&publisher, keys, values, ctx);
        display::update_version(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    // === Collection Management ===

    /// Create a new NFT collection
    public fun create_collection(
        name: vector<u8>,
        description: vector<u8>,
        max_supply: u64,
        mint_price: u64,
        mint_duration_ms: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): ID {
        let current_time = clock::timestamp_ms(clock);

        let collection = Collection {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            creator: tx_context::sender(ctx),
            total_supply: 0,
            max_supply,
            mint_price,
            mint_start_time: current_time,
            mint_end_time: current_time + mint_duration_ms,
            is_active: false,
        };

        let collection_id = object::uid_to_inner(&collection.id);

        // Create admin capability
        let admin_cap = AdminCap {
            id: object::new(ctx),
            collection_id,
        };

        event::emit(CollectionCreated {
            collection_id,
            name: collection.name,
            creator: collection.creator,
            max_supply,
        });

        transfer::transfer(admin_cap, tx_context::sender(ctx));
        transfer::share_object(collection);

        collection_id
    }

    /// Activate minting for the collection
    public fun activate_minting(
        collection: &mut Collection,
        admin_cap: &AdminCap,
        _ctx: &TxContext
    ) {
        assert!(admin_cap.collection_id == object::uid_to_inner(&collection.id), ENotAuthorized);
        collection.is_active = true;
    }

    // === NFT Minting ===

    /// Public mint function with time and payment checks
    public entry fun mint_nft(
        collection: &mut Collection,
        name: vector<u8>,
        description: vector<u8>,
        image_url: vector<u8>,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Check if minting is active
        assert!(collection.is_active, EMintNotActive);
        assert!(is_mint_active(collection, clock), EMintNotActive);

        // Check payment
        assert!(coin::value(&payment) >= collection.mint_price, EInsufficientPayment);

        // Check supply
        assert!(collection.total_supply < collection.max_supply, EMaxSupplyReached);

        // Transfer payment to creator
        transfer::public_transfer(payment, collection.creator);

        // Mint NFT
        let mut nft = SimpleNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            image_url: string::utf8(image_url),
            creator: tx_context::sender(ctx),
            attributes: vec_map::empty(),
        };

        let nft_id = object::uid_to_inner(&nft.id);
        collection.total_supply = collection.total_supply + 1;

        // Add collection reference as dynamic field
        df::add(&mut nft.id, b"collection_id", object::uid_to_inner(&collection.id));
        df::add(&mut nft.id, b"edition_number", collection.total_supply);

        event::emit(NFTMinted {
            nft_id,
            name: nft.name,
            recipient: tx_context::sender(ctx),
            collection_id: object::uid_to_inner(&collection.id),
            edition_number: collection.total_supply,
        });

        transfer::transfer(nft, tx_context::sender(ctx));
    }

    /// Admin mint function (free for creator)
    public fun admin_mint(
        collection: &mut Collection,
        admin_cap: &AdminCap,
        name: vector<u8>,
        description: vector<u8>,
        image_url: vector<u8>,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(admin_cap.collection_id == object::uid_to_inner(&collection.id), ENotAuthorized);
        assert!(collection.total_supply < collection.max_supply, EMaxSupplyReached);

        let mut nft = SimpleNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            image_url: string::utf8(image_url),
            creator: collection.creator,
            attributes: vec_map::empty(),
        };

        let nft_id = object::uid_to_inner(&nft.id);
        collection.total_supply = collection.total_supply + 1;

        df::add(&mut nft.id, b"collection_id", object::uid_to_inner(&collection.id));
        df::add(&mut nft.id, b"edition_number", collection.total_supply);

        event::emit(NFTMinted {
            nft_id,
            name: nft.name,
            recipient,
            collection_id: object::uid_to_inner(&collection.id),
            edition_number: collection.total_supply,
        });

        transfer::transfer(nft, recipient);
    }

    // === NFT Utilities ===

    /// Add attribute to NFT (only creator can do this)
    public fun add_attribute(
        nft: &mut SimpleNFT,
        key: vector<u8>,
        value: vector<u8>,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == nft.creator, ENotAuthorized);
        vec_map::insert(&mut nft.attributes, string::utf8(key), string::utf8(value));
    }

    /// Add dynamic field to NFT
    public fun add_dynamic_field<T: store>(
        nft: &mut SimpleNFT,
        key: vector<u8>,
        value: T,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == nft.creator, ENotAuthorized);
        df::add(&mut nft.id, key, value);
    }

    /// Get dynamic field from NFT
    public fun get_dynamic_field<T: store>(
        nft: &SimpleNFT,
        key: vector<u8>
    ): &T {
        df::borrow(&nft.id, key)
    }

    // === View Functions ===

    /// Check if minting is currently active
    public fun is_mint_active(collection: &Collection, clock: &Clock): bool {
        if (!collection.is_active) return false;

        let current_time = clock::timestamp_ms(clock);
        current_time >= collection.mint_start_time &&
        current_time <= collection.mint_end_time &&
        collection.total_supply < collection.max_supply
    }

    /// Get NFT information
    public fun get_nft_info(nft: &SimpleNFT): (String, String, String, address) {
        (nft.name, nft.description, nft.image_url, nft.creator)
    }

    /// Get collection information
    public fun get_collection_info(collection: &Collection): (String, String, address, u64, u64, u64, bool, u64, u64) {
        (
            collection.name,
            collection.description,
            collection.creator,
            collection.total_supply,
            collection.max_supply,
            collection.mint_price,
            collection.is_active,
            collection.mint_start_time,
            collection.mint_end_time
        )
    }

    /// Get NFT attributes
    public fun get_nft_attributes(nft: &SimpleNFT): &VecMap<String, String> {
        &nft.attributes
    }

    /// Get time remaining for mint
    public fun get_time_remaining(collection: &Collection, clock: &Clock): u64 {
        let current_time = clock::timestamp_ms(clock);
        if (current_time >= collection.mint_end_time) {
            0
        } else {
            collection.mint_end_time - current_time
        }
    }

    // === Test Functions ===
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(SIMPLE_ART_NFT {}, ctx);
    }
}