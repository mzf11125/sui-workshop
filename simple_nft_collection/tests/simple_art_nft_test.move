#[test_only]
module simple_nft_collection::simple_nft_test {
    use simple_nft_collection::simple_art_nft::{Self, Collection, AdminCap, SimpleNFT};
    use sui::test_scenario;
    use sui::clock;
    use sui::coin;
    use sui::sui::SUI;

    const ADMIN: address = @0xAD;
    const USER: address = @0xAB;

    #[test]
    fun test_complete_nft_flow() {
        let mut scenario = test_scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        clock::set_for_testing(&mut clock, 1000000);

        // Initialize
        {
            simple_art_nft::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        // Create collection
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = simple_art_nft::create_collection(
                b"Simple Art Collection",
                b"A collection of simple art NFTs",
                100, // max supply
                1000000000, // 1 SUI mint price
                7 * 24 * 60 * 60 * 1000, // 7 days duration
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            transfer::public_transfer(admin_cap, ADMIN);
        };

        // Activate minting
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = test_scenario::take_shared<Collection>(&scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);

            simple_art_nft::activate_minting(&mut collection, &admin_cap, test_scenario::ctx(&mut scenario));

            // Verify minting is active
            assert!(simple_art_nft::is_mint_active(&collection, &clock), 0);

            test_scenario::return_shared(collection);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };

        // User mints NFT
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut collection = test_scenario::take_shared<Collection>(&scenario);
            let payment = coin::mint_for_testing<SUI>(1000000000, test_scenario::ctx(&mut scenario));

            simple_art_nft::mint_nft(
                &mut collection,
                b"My First NFT",
                b"This is my first NFT",
                b"https://example.com/nft1.png",
                payment,
                &clock,
                test_scenario::ctx(&mut scenario)
            );

            test_scenario::return_shared(collection);
        };

        // Verify NFT creation
        test_scenario::next_tx(&mut scenario, USER);
        {
            let nft = test_scenario::take_from_sender<SimpleNFT>(&scenario);
            let (name, _description, _image_url, creator) = simple_art_nft::get_nft_info(&nft);

            assert!(name == std::string::utf8(b"My First NFT"), 0);
            assert!(creator == USER, 1);

            // Check dynamic fields
            let edition: &u64 = simple_art_nft::get_dynamic_field(&nft, b"edition_number");
            assert!(*edition == 1, 2);

            test_scenario::return_to_sender(&scenario, nft);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_time_based_minting() {
        let mut scenario = test_scenario::begin(ADMIN);
        let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        let start_time = 1000000;
        let duration = 24 * 60 * 60 * 1000; // 1 day

        clock::set_for_testing(&mut clock, start_time);

        // Setup
        {
            simple_art_nft::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = simple_art_nft::create_collection(
                b"Time Limited",
                b"24 hour mint window",
                10,
                0, // Free mint
                duration,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            transfer::public_transfer(admin_cap, ADMIN);
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = test_scenario::take_shared<Collection>(&scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);

            simple_art_nft::activate_minting(&mut collection, &admin_cap, test_scenario::ctx(&mut scenario));
            assert!(simple_art_nft::is_mint_active(&collection, &clock), 0);

            test_scenario::return_shared(collection);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };

        // Fast forward past end time
        clock::set_for_testing(&mut clock, start_time + duration + 1000);

        test_scenario::next_tx(&mut scenario, USER);
        {
            let collection = test_scenario::take_shared<Collection>(&scenario);
            assert!(!simple_art_nft::is_mint_active(&collection, &clock), 0);
            test_scenario::return_shared(collection);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_nft_attributes() {
        let mut scenario = test_scenario::begin(ADMIN);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        // Setup and mint NFT
        {
            simple_art_nft::init_for_testing(test_scenario::ctx(&mut scenario));
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = simple_art_nft::create_collection(
                b"Attribute Test",
                b"Testing attributes",
                10,
                0,
                365 * 24 * 60 * 60 * 1000,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            transfer::public_transfer(admin_cap, ADMIN);
        };

        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = test_scenario::take_shared<Collection>(&scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);

            simple_art_nft::activate_minting(&mut collection, &admin_cap, test_scenario::ctx(&mut scenario));

            // Admin mint NFT to self
            simple_art_nft::admin_mint(
                &mut collection,
                &admin_cap,
                b"Attribute NFT",
                b"NFT for testing attributes",
                b"https://example.com/attr.png",
                ADMIN,
                test_scenario::ctx(&mut scenario)
            );

            test_scenario::return_shared(collection);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };

        // Add attributes
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut nft = test_scenario::take_from_sender<SimpleNFT>(&scenario);

            simple_art_nft::add_attribute(&mut nft, b"Color", b"Blue", test_scenario::ctx(&mut scenario));
            simple_art_nft::add_attribute(&mut nft, b"Rarity", b"Rare", test_scenario::ctx(&mut scenario));
            simple_art_nft::add_dynamic_field(&mut nft, b"special_number", 42u64, test_scenario::ctx(&mut scenario));

            let attributes = simple_art_nft::get_nft_attributes(&nft);
            assert!(sui::vec_map::size(attributes) == 2, 0);

            let special_number: &u64 = simple_art_nft::get_dynamic_field(&nft, b"special_number");
            assert!(*special_number == 42, 1);

            test_scenario::return_to_sender(&scenario, nft);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario);
    }
}