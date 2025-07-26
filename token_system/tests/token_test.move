#[test_only]
module token_system::token_test {
    use token_system::my_token::{Self, AdminCap, TokenVault, MY_TOKEN};
    use sui::coin::{Self, TreasuryCap};
    use sui::test_scenario::{Self};
    
    #[test]
    fun test_token_minting() {
        let admin = @0xAD31;
        let user = @0xABBA;
        
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize the token system
        {
            my_token::init_for_testing(test_scenario::ctx(&mut scenario));
        };
        
        // Admin mints tokens
        test_scenario::next_tx(&mut scenario, admin);
        {
            let mut treasury = test_scenario::take_from_sender<TreasuryCap<MY_TOKEN>>(&scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            
            // Mint 1000 tokens to user
            my_token::mint(
                &admin_cap,
                &mut treasury,
                1000000000, // 1000 tokens with 8 decimals
                user,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_to_sender(&scenario, treasury);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        
        // User receives tokens
        test_scenario::next_tx(&mut scenario, user);
        {
            let coin = test_scenario::take_from_sender<sui::coin::Coin<MY_TOKEN>>(&scenario);
            assert!(coin::value(&coin) == 1000000000, 0);
            test_scenario::return_to_sender(&scenario, coin);
        };
        
        test_scenario::end(scenario);
    }
    
    #[test]
    fun test_vault_operations() {
        let admin = @0xAD31;
        let mut scenario = test_scenario::begin(admin);
        
        // Initialize
        {
            my_token::init_for_testing(test_scenario::ctx(&mut scenario));
        };
        
        // Test vault operations
        test_scenario::next_tx(&mut scenario, admin);
        {
            let vault = test_scenario::take_shared<TokenVault>(&scenario);
            let mut treasury = test_scenario::take_from_sender<TreasuryCap<MY_TOKEN>>(&scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            
            // Mint tokens to admin
            my_token::mint(
                &admin_cap,
                &mut treasury,
                500000000,
                admin,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_to_sender(&scenario, treasury);
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(vault);
        };
        
        // Deposit to vault
        test_scenario::next_tx(&mut scenario, admin);
        {
            let mut vault = test_scenario::take_shared<TokenVault>(&scenario);
            let coin = test_scenario::take_from_sender<sui::coin::Coin<MY_TOKEN>>(&scenario);
            
            my_token::deposit_to_vault(&mut vault, coin);
            assert!(my_token::vault_balance(&vault) == 500000000, 0);
            
            test_scenario::return_shared(vault);
        };
        
        test_scenario::end(scenario);
    }
}