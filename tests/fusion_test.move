#[test_only]
module play::fusion_test {
    use std::signer;
    use std::aptos_hash;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_test_helpers::transaction_test_helpers;
    use crate::fusion;

    const E_NOT_INITIALIZED: u64 = 1;

    #[test(sender = @0x1, recipient = @0x2)]
    public entry fun test_init_fusion_store(
        sender: &signer,
        recipient: &signer,
    ) {
        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);

        aptos_coin::mint(sender, 1000);
        aptos_coin::mint(recipient, 1000);

        fusion::init_fusion_store(sender);
        assert!(exists<fusion::FusionStore>(sender_addr));
    }

    #[test(sender = @0x1, recipient = @0x2)]
    public entry fun test_initiate_swap(
        sender: &signer,
        recipient: &signer,
    ) {
        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);

        aptos_coin::mint(sender, 1000);
        aptos_coin::mint(recipient, 1000);

        fusion::init_fusion_store(sender);

        let secret = b"secret";
        let secret_hash = aptos_hash::keccak256(secret);

        transaction_test_helpers::run_as_test_account(sender, |sender_signer| {
            fusion::initiate_swap(
                sender_signer,
                recipient_addr,
                100,
                1,
                2,
                recipient_addr,
                secret_hash,
                timestamp::now_seconds() + 1000,
            );
        });
    }

    #[test(sender = @0x1, recipient = @0x2)]
    public entry fun test_claim_swap(
        sender: &signer,
        recipient: &signer,
    ) {
        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);

        aptos_coin::mint(sender, 1000);
        aptos_coin::mint(recipient, 1000);

        fusion::init_fusion_store(sender);

        let secret = b"secret";
        let secret_hash = aptos_hash::keccak256(secret);

        transaction_test_helpers::run_as_test_account(sender, |sender_signer| {
            fusion::initiate_swap(
                sender_signer,
                recipient_addr,
                100,
                1,
                2,
                recipient_addr,
                secret_hash,
                timestamp::now_seconds() + 1000,
            );
        });

        transaction_test_helpers::run_as_test_account(recipient, |recipient_signer| {
            fusion::claim_swap(
                recipient_signer,
                sender_addr,
                secret,
            );
        });
    }

    #[test(sender = @0x1, recipient = @0x2)]
    public entry fun test_refund_swap(
        sender: &signer,
        recipient: &signer,
    ) {
        let sender_addr = signer::address_of(sender);
        let recipient_addr = signer::address_of(recipient);

        aptos_coin::mint(sender, 1000);
        aptos_coin::mint(recipient, 1000);

        fusion::init_fusion_store(sender);

        let secret = b"secret";
        let secret_hash = aptos_hash::keccak256(secret);

        transaction_test_helpers::run_as_test_account(sender, |sender_signer| {
            fusion::initiate_swap(
                sender_signer,
                recipient_addr,
                100,
                1,
                2,
                recipient_addr,
                secret_hash,
                timestamp::now_seconds() + 1,
            );
        });

        timestamp::fast_forward_seconds(2);

        transaction_test_helpers::run_as_test_account(sender, |sender_signer| {
            fusion::refund_swap(
                sender_signer,
                secret_hash,
            );
        });
    }
} 