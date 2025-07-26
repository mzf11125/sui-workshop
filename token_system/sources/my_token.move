module token_system::my_token {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::event;

    /// One-Time Witness for the token
    public struct MY_TOKEN has drop {}

    /// Admin capability for minting tokens
    public struct AdminCap has key, store {
        id: sui::object::UID,
    }

    /// Vault for storing tokens with access control
    public struct TokenVault has key {
        id: sui::object::UID,
        balance: Balance<MY_TOKEN>,
        admin: address,
    }

    /// Event emitted when tokens are minted
    public struct TokenMinted has copy, drop {
        amount: u64,
        recipient: address,
    }

    /// Event emitted when tokens are burned
    public struct TokenBurned has copy, drop {
        amount: u64,
    }

    /// Initialize the token system
    fun init(witness: MY_TOKEN, ctx: &mut sui::tx_context::TxContext) {
        // Create the currency
        let (treasury, metadata) = coin::create_currency(
            witness,
            8, // 8 decimals
            b"MTK",
            b"MyToken",
            b"A sample token for learning Sui",
            std::option::none(),
            ctx
        );

        // Freeze the metadata so it can't be changed
        sui::transfer::public_freeze_object(metadata);

        // Create admin capability
        let admin_cap = AdminCap {
            id: sui::object::new(ctx),
        };

        // Create a vault for storing tokens
        let vault = TokenVault {
            id: sui::object::new(ctx),
            balance: balance::zero(),
            admin: sui::tx_context::sender(ctx),
        };

        // Transfer treasury and admin cap to deployer
        sui::transfer::public_transfer(treasury, sui::tx_context::sender(ctx));
        sui::transfer::public_transfer(admin_cap, sui::tx_context::sender(ctx));
        sui::transfer::share_object(vault);
    }

    /// Mint new tokens (requires AdminCap)
    public fun mint(
        _: &AdminCap,
        treasury: &mut TreasuryCap<MY_TOKEN>,
        amount: u64,
        recipient: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let minted_coin = coin::mint(treasury, amount, ctx);
        sui::transfer::public_transfer(minted_coin, recipient);
        
        event::emit(TokenMinted {
            amount,
            recipient,
        });
    }

    /// Burn tokens
    public fun burn(
        treasury: &mut TreasuryCap<MY_TOKEN>,
        coin: Coin<MY_TOKEN>
    ) {
        let amount = coin::value(&coin);
        coin::burn(treasury, coin);
        
        event::emit(TokenBurned {
            amount,
        });
    }

    /// Deposit tokens into vault
    public fun deposit_to_vault(
        vault: &mut TokenVault,
        coin: Coin<MY_TOKEN>
    ) {
        let deposit_balance = coin::into_balance(coin);
        balance::join(&mut vault.balance, deposit_balance);
    }

    /// Withdraw tokens from vault (only admin)
    public fun withdraw_from_vault(
        vault: &mut TokenVault,
        amount: u64,
        ctx: &mut sui::tx_context::TxContext
    ): Coin<MY_TOKEN> {
        assert!(sui::tx_context::sender(ctx) == vault.admin, 0);
        let withdrawn_balance = balance::split(&mut vault.balance, amount);
        coin::from_balance(withdrawn_balance, ctx)
    }

    /// Get vault balance
    public fun vault_balance(vault: &TokenVault): u64 {
        balance::value(&vault.balance)
    }

    /// Transfer admin rights
    public fun transfer_admin(
        vault: &mut TokenVault,
        new_admin: address,
        ctx: &sui::tx_context::TxContext
    ) {
        assert!(sui::tx_context::sender(ctx) == vault.admin, 0);
        vault.admin = new_admin;
    }

    /// Check if address is admin
    public fun is_admin(vault: &TokenVault, addr: address): bool {
        vault.admin == addr
    }

    // === Test Functions ===
    #[test_only]
    public fun init_for_testing(ctx: &mut sui::tx_context::TxContext) {
        init(MY_TOKEN {}, ctx);
    }
}