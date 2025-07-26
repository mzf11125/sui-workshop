module counter_project::counter {

    /// Counter object that can be incremented
    public struct Counter has key, store {
        id: sui::object::UID,
        value: u64,
    }

    /// Initialize function - runs once when module is published
    fun init(ctx: &mut sui::tx_context::TxContext) {
        let counter = create_counter(ctx);
        // Share the counter so anyone can use it
        sui::transfer::share_object(counter);
    }

    /// Create a new counter with value 0
    fun create_counter(ctx: &mut sui::tx_context::TxContext): Counter {
        Counter {
            id: sui::object::new(ctx),
            value: 0,
        }
    }

    /// Get the current counter value
    public fun get_value(counter: &Counter): u64 {
        counter.value
    }

    /// Increment the counter by 1
    public fun increment(counter: &mut Counter) {
        counter.value = counter.value + 1;
    }

    /// Reset counter to 0
    public fun reset(counter: &mut Counter) {
        counter.value = 0;
    }

    /// Test-only function to create counter for unit tests
    #[test_only]
    public fun create_counter_for_testing(ctx: &mut sui::tx_context::TxContext): Counter {
        create_counter(ctx)
    }
}