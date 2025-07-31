#[test_only]
module play::fusion_test {
    use std::signer;
    use std::aptos_hash;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use play::fusion;

    #[test(sender = @0x123)]
    fun test_init_fusion_store(sender: signer) {
        let sender_addr = signer::address_of(&sender);
        
        // Assert that the resources do not exist initially.
        assert!(!fusion::has_fusion_store(sender_addr), 0);
        
        fusion::init_fusion_store(&sender);

        // Assert that the resources have been created after the call.
        assert!(fusion::has_fusion_store(sender_addr), 1);
    }

    #[test(sender = @0x123)]
    #[expected_failure(abort_code = 5)]
    fun test_init_fusion_store_already_exists(sender: signer) {
        fusion::init_fusion_store(&sender);
        fusion::init_fusion_store(&sender);
    }
}