#[test_only]
module play::fusion_test {
    use std::signer;
    use std::aptos_hash;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use play::fusion;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::aptos_account;

    #[test_only]
    fun setup_timestamp(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
    }

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
    #[expected_failure(abort_code = 5, location = play::fusion)]
    fun test_init_fusion_store_already_exists(sender: signer) {
        fusion::init_fusion_store(&sender);
        fusion::init_fusion_store(&sender);
    }

    #[test(sender = @0x123, recipient = @0x456, aptos_framework = @0x1)]
    fun test_initiate_swap_success(sender: &signer, recipient: &signer, aptos_framework: &signer) {
        setup_timestamp(aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);
        let amount = 1_000_000;

        aptos_account::create_account(sender_addr);
        coin::deposit(sender_addr, coin::mint(10_000_000, &mint_cap));

        // Initialize fusion store for the sender
        fusion::init_fusion_store(sender);

        // Get resource account address
        let resource_addr = account::create_resource_address(&sender_addr, b"fusion_store");
        
        // Define swap parameters
        let secret = b"this is a secret";
        let secret_hash = aptos_hash::keccak256(secret);
        let expiration_time = timestamp::now_seconds() + 3600;

        // Call initiate_swap
        fusion::initiate_swap(
            sender,
            recipient_addr,
            amount,
            1, // chain_id
            2, // dst_chain_id
            @0xABC, // dst_address
            secret_hash,
            expiration_time
        );

        // Assert the balance of the resource account
        assert!(coin::balance<AptosCoin>(resource_addr) == amount, 2);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test(sender = @0x123, recipient = @0x456, aptos_framework = @0x1)]
    fun test_claim_swap_success(sender: &signer, recipient: &signer, aptos_framework: &signer) {
        setup_timestamp(aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);
        let amount = 1_000_000;

        aptos_account::create_account(sender_addr);
        aptos_account::create_account(recipient_addr);
        coin::deposit(sender_addr, coin::mint(10_000_000, &mint_cap));

        // Initialize fusion store for the sender
        fusion::init_fusion_store(sender);

        // Define swap parameters
        let secret = b"this is a secret";
        let secret_hash = aptos_hash::keccak256(secret);
        let expiration_time = timestamp::now_seconds() + 3600;

        // Call initiate_swap
        fusion::initiate_swap(
            sender,
            recipient_addr,
            amount,
            1, // chain_id
            2, // dst_chain_id
            @0xABC, // dst_address
            secret_hash,
            expiration_time
        );

        let initial_recipient_balance = coin::balance<AptosCoin>(recipient_addr);

        // Claim the swap
        fusion::claim_swap(recipient, sender_addr, secret);

        // Assert the recipient's new balance
        assert!(coin::balance<AptosCoin>(recipient_addr) == initial_recipient_balance + amount, 3);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test(sender = @0x123, recipient = @0x456, aptos_framework = @0x1)]
    fun test_refund_swap_success(sender: &signer, recipient: &signer, aptos_framework: &signer) {
        setup_timestamp(aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);
        let amount = 1_000_000;

        aptos_account::create_account(sender_addr);
        coin::deposit(sender_addr, coin::mint(10_000_000, &mint_cap));

        // Initialize fusion store for the sender
        fusion::init_fusion_store(sender);
        
        // Define swap parameters
        let secret = b"this is a secret";
        let secret_hash = aptos_hash::keccak256(secret);
        let expiration_time = timestamp::now_seconds() + 1; // Expires in 1 second

        // Call initiate_swap
        fusion::initiate_swap(
            sender,
            recipient_addr,
            amount,
            1, // chain_id
            2, // dst_chain_id
            @0xABC, // dst_address
            secret_hash,
            expiration_time
        );

        // Advance time to after the expiration
        timestamp::fast_forward_seconds(2);

        let initial_sender_balance = coin::balance<AptosCoin>(sender_addr);

        // Refund the swap
        fusion::refund_swap(sender, secret_hash);

        // Assert the sender's new balance
        assert!(coin::balance<AptosCoin>(sender_addr) == initial_sender_balance + amount, 4);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test(sender = @0x123, recipient = @0x456, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 2, location = play::fusion)]
    fun test_claim_swap_wrong_secret(sender: &signer, recipient: &signer, aptos_framework: &signer) {
        setup_timestamp(aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);
        let amount = 1_000_000;

        aptos_account::create_account(sender_addr);
        aptos_account::create_account(recipient_addr);
        coin::deposit(sender_addr, coin::mint(10_000_000, &mint_cap));

        // Initialize fusion store for the sender
        fusion::init_fusion_store(sender);

        // Define swap parameters
        let secret = b"this is a secret";
        let secret_hash = aptos_hash::keccak256(secret);
        let expiration_time = timestamp::now_seconds() + 3600;

        // Call initiate_swap
        fusion::initiate_swap(
            sender,
            recipient_addr,
            amount,
            1, // chain_id
            2, // dst_chain_id
            @0xABC, // dst_address
            secret_hash,
            expiration_time
        );

        // Claim the swap with the wrong secret
        let wrong_secret = b"this is the wrong secret";
        fusion::claim_swap(recipient, sender_addr, wrong_secret);

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test(sender = @0x123, recipient = @0x456, wrong_recipient = @0x789, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 9, location = play::fusion)]
    fun test_claim_swap_wrong_recipient(sender: &signer, recipient: &signer, wrong_recipient: &signer, aptos_framework: &signer) {
        setup_timestamp(aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);
        let wrong_recipient_addr = signer::address_of(wrong_recipient);
        let amount = 1_000_000;

        aptos_account::create_account(sender_addr);
        aptos_account::create_account(recipient_addr);
        aptos_account::create_account(wrong_recipient_addr);
        coin::deposit(sender_addr, coin::mint(10_000_000, &mint_cap));

        // Initialize fusion store for the sender
        fusion::init_fusion_store(sender);

        // Define swap parameters
        let secret = b"this is a secret";
        let secret_hash = aptos_hash::keccak256(secret);
        let expiration_time = timestamp::now_seconds() + 3600;

        // Call initiate_swap
        fusion::initiate_swap(
            sender,
            recipient_addr,
            amount,
            1, // chain_id
            2, // dst_chain_id
            @0xABC, // dst_address
            secret_hash,
            expiration_time
        );

        // Claim the swap with the wrong recipient
        fusion::claim_swap(wrong_recipient, sender_addr, secret);

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test(sender = @0x123, recipient = @0x456, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 4, location = play::fusion)]
    fun test_refund_swap_not_expired(sender: &signer, recipient: &signer, aptos_framework: &signer) {
        setup_timestamp(aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);
        let amount = 1_000_000;

        aptos_account::create_account(sender_addr);
        coin::deposit(sender_addr, coin::mint(10_000_000, &mint_cap));

        // Initialize fusion store for the sender
        fusion::init_fusion_store(sender);
        
        // Define swap parameters
        let secret = b"this is a secret";
        let secret_hash = aptos_hash::keccak256(secret);
        let expiration_time = timestamp::now_seconds() + 3600; // Expires in 1 hour

        // Call initiate_swap
        fusion::initiate_swap(
            sender,
            recipient_addr,
            amount,
            1, // chain_id
            2, // dst_chain_id
            @0xABC, // dst_address
            secret_hash,
            expiration_time
        );

        // Refund the swap
        fusion::refund_swap(sender, secret_hash);

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test(sender = @0x123, recipient = @0x456, wrong_sender = @0x789, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 2, location = play::fusion)]
    fun test_refund_swap_wrong_sender(sender: &signer, recipient: &signer, wrong_sender: &signer, aptos_framework: &signer) {
        setup_timestamp(aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);
        let wrong_sender_addr = signer::address_of(wrong_sender);
        let amount = 1_000_000;

        aptos_account::create_account(sender_addr);
        aptos_account::create_account(wrong_sender_addr);
        coin::deposit(sender_addr, coin::mint(10_000_000, &mint_cap));

        // Initialize fusion store for the sender and the wrong sender
        fusion::init_fusion_store(sender);
        fusion::init_fusion_store(wrong_sender);
        
        // Define swap parameters
        let secret = b"this is a secret";
        let secret_hash = aptos_hash::keccak256(secret);
        let expiration_time = timestamp::now_seconds() + 1; // Expires in 1 second

        // Call initiate_swap
        fusion::initiate_swap(
            sender,
            recipient_addr,
            amount,
            1, // chain_id
            2, // dst_chain_id
            @0xABC, // dst_address
            secret_hash,
            expiration_time
        );

        // Advance time to after the expiration
        timestamp::fast_forward_seconds(2);

        // Refund the swap with the wrong sender
        fusion::refund_swap(wrong_sender, secret_hash);

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test(sender = @0x123, recipient = @0x456, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 1, location = play::fusion)]
    fun test_initiate_swap_duplicate_secret(sender: &signer, recipient: &signer, aptos_framework: &signer) {
        setup_timestamp(aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);
        let amount = 1_000_000;

        aptos_account::create_account(sender_addr);
        coin::deposit(sender_addr, coin::mint(10_000_000, &mint_cap));

        // Initialize fusion store for the sender
        fusion::init_fusion_store(sender);
        
        // Define swap parameters
        let secret = b"this is a secret";
        let secret_hash = aptos_hash::keccak256(secret);
        let expiration_time = timestamp::now_seconds() + 3600;

        // Call initiate_swap
        fusion::initiate_swap(
            sender,
            recipient_addr,
            amount,
            1, // chain_id
            2, // dst_chain_id
            @0xABC, // dst_address
            secret_hash,
            expiration_time
        );

        // Call initiate_swap again with the same secret
        fusion::initiate_swap(
            sender,
            recipient_addr,
            amount,
            1, // chain_id
            2, // dst_chain_id
            @0xABC, // dst_address
            secret_hash,
            expiration_time
        );

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }
}
