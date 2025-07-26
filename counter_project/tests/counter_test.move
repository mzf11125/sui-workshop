#[test_only]
module counter_project::counter_test {
    use counter_project::counter;
    use sui::test_scenario;

    #[test]
    fun test_initial_value() {
        let admin = @0xABBA;
        let mut scenario = test_scenario::begin(admin);
        let ctx = test_scenario::ctx(&mut scenario);
        let counter_obj = counter::create_counter_for_testing(ctx);
        assert!(counter::get_value(&counter_obj) == 0, 0);
        
        // Properly destroy the counter object
        sui::test_utils::destroy(counter_obj);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_increment() {
        let admin = @0xABBA;
        let mut scenario = test_scenario::begin(admin);
        let ctx = test_scenario::ctx(&mut scenario);
        let mut counter_obj = counter::create_counter_for_testing(ctx);
        counter::increment(&mut counter_obj);
        assert!(counter::get_value(&counter_obj) == 1, 0);
        
        // Properly destroy the counter object
        sui::test_utils::destroy(counter_obj);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_reset() {
        let admin = @0xABBA;
        let mut scenario = test_scenario::begin(admin);
        let ctx = test_scenario::ctx(&mut scenario);
        let mut counter_obj = counter::create_counter_for_testing(ctx);
        counter::increment(&mut counter_obj);
        counter::increment(&mut counter_obj);
        counter::reset(&mut counter_obj);
        assert!(counter::get_value(&counter_obj) == 0, 0);
        
        // Properly destroy the counter object
        sui::test_utils::destroy(counter_obj);
        test_scenario::end(scenario);
    }
}