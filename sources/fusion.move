module play::fusion {
    use std::signer;
    use std::aptos_hash;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use std::table;

    /// The swap has already been initiated.
    const E_SWAP_ALREADY_INITIATED: u64 = 1;
    /// The swap has not yet been initiated.
    const E_SWAP_NOT_INITIATED: u64 = 2;
    /// The secret provided is incorrect.
    const E_INCORRECT_SECRET: u64 = 3;
    /// The swap has not yet expired.
    const E_SWAP_NOT_EXPIRED: u64 = 4;
    /// The fusion store already exists.
    const E_FUSION_STORE_ALREADY_EXISTS: u64 = 5;
    const E_FUSION_STORE_NOT_FOUND: u64 = 6;
    const E_SWAP_DATA_NOT_FOUND: u64 = 7;

    struct FusionStore has key {
        signer_cap: aptos_framework::account::SignerCapability,
    }

    struct Swap has store {
        sender: address,
        recipient: address,
        amount: u64,
        chain_id: u64,
        dst_chain_id: u64,
        dst_address: address,
        secret_hash: vector<u8>,
        expiration_time: u64,
    }
    
    struct SwapData has key {
        swaps: table::Table<vector<u8>, Swap>,
    }

    struct Events has key {
        swap_initiated: event::EventHandle<SwapInitiated>,
        swap_claimed: event::EventHandle<SwapClaimed>,
        swap_refunded: event::EventHandle<SwapRefunded>,
    }

    struct SwapInitiated has drop, store {
        swap_id: vector<u8>,
        sender: address,
        recipient: address,
        amount: u64,
        chain_id: u64,
        expiration_time: u64,
    }

    struct SwapClaimed has drop, store {
        swap_id: vector<u8>,
    }

    struct SwapRefunded has drop, store {
        swap_id: vector<u8>,
    }

    fun init_module(sender: &signer) {
        move_to(sender, Events {
            swap_initiated: event::new_event_handle<SwapInitiated>(sender),
            swap_claimed: event::new_event_handle<SwapClaimed>(sender),
            swap_refunded: event::new_event_handle<SwapRefunded>(sender),
        });
    }

    public entry fun init_fusion_store(sender: &signer) {
        let sender_addr = signer::address_of(sender);
        assert!(!exists<FusionStore>(sender_addr), E_FUSION_STORE_ALREADY_EXISTS);
        let (resource_signer, resource_cap) = aptos_framework::account::create_resource_account(sender, b"fusion_store");
        let fusion_store = FusionStore { signer_cap: resource_cap };
        move_to(sender, fusion_store);

        let swap_data = SwapData { swaps: table::new() };
        move_to(&resource_signer, swap_data);
    }
    
    fun init_events(account: &signer) {
        move_to(account, Events {
            swap_initiated: event::new_event_handle<SwapInitiated>(account),
            swap_claimed: event::new_event_handle<SwapClaimed>(account),
            swap_refunded: event::new_event_handle<SwapRefunded>(account),
        });
    }

    public entry fun initiate_swap(
        sender: &signer,
        recipient: address,
        amount: u64,
        chain_id: u64,
        dst_chain_id: u64,
        dst_address: address,
        secret_hash: vector<u8>,
        expiration_time: u64,
    ) acquires FusionStore, SwapData, Events {
        let sender_addr = signer::address_of(sender);
        assert!(exists<FusionStore>(sender_addr), E_FUSION_STORE_NOT_FOUND);
        let fusion_store = borrow_global<FusionStore>(sender_addr);

        let resource_signer = aptos_framework::account::create_signer_with_capability(&fusion_store.signer_cap);
        let resource_addr = signer::address_of(&resource_signer);

        assert!(exists<SwapData>(resource_addr), E_SWAP_DATA_NOT_FOUND);
        let swap_data = borrow_global_mut<SwapData>(resource_addr);
        assert!(!table::contains(&swap_data.swaps, secret_hash), E_SWAP_ALREADY_INITIATED);

        coin::transfer<AptosCoin>(sender, resource_addr, amount);

        let swap = Swap {
            sender: sender_addr,
            recipient,
            amount,
            chain_id,
            dst_chain_id,
            dst_address,
            secret_hash,
            expiration_time,
        };
        table::add(&mut swap_data.swaps, secret_hash, swap);

        let events = borrow_global_mut<Events>(@play);
        event::emit_event(&mut events.swap_initiated, SwapInitiated {
            swap_id: secret_hash,
            sender: sender_addr,
            recipient,
            amount,
            chain_id,
            expiration_time,
        });
    }

    public entry fun claim_swap(
        recipient: &signer,
        sender_addr: address,
        secret: vector<u8>,
    ) acquires FusionStore, SwapData, Events {
        let recipient_addr = signer::address_of(recipient);
        assert!(exists<FusionStore>(sender_addr), E_FUSION_STORE_NOT_FOUND);
        let fusion_store = borrow_global<FusionStore>(sender_addr);
        let resource_signer = aptos_framework::account::create_signer_with_capability(&fusion_store.signer_cap);
        let resource_addr = signer::address_of(&resource_signer);

        assert!(exists<SwapData>(resource_addr), E_SWAP_DATA_NOT_FOUND);
        let swap_data = borrow_global_mut<SwapData>(resource_addr);
        let secret_hash = aptos_hash::keccak256(secret);
        assert!(table::contains(&swap_data.swaps, secret_hash), E_SWAP_NOT_INITIATED);

        let swap = table::borrow_mut(&mut swap_data.swaps, secret_hash);
        assert!(swap.recipient == recipient_addr, E_SWAP_NOT_INITIATED);
        
        assert!(aptos_hash::keccak256(secret) == swap.secret_hash, E_INCORRECT_SECRET);

        coin::transfer<AptosCoin>(&resource_signer, recipient_addr, swap.amount);

        table::remove(&mut swap_data.swaps, secret_hash);
        
        let events = borrow_global_mut<Events>(@play);
        event::emit_event(&mut events.swap_claimed, SwapClaimed { swap_id: secret_hash });
    }

    public entry fun refund_swap(
        sender: &signer,
        secret_hash: vector<u8>,
    ) acquires FusionStore, SwapData, Events {
        let sender_addr = signer::address_of(sender);
        assert!(exists<FusionStore>(sender_addr), E_FUSION_STORE_NOT_FOUND);
        let fusion_store = borrow_global<FusionStore>(sender_addr);
        let resource_signer = aptos_framework::account::create_signer_with_capability(&fusion_store.signer_cap);
        let resource_addr = signer::address_of(&resource_signer);

        assert!(exists<SwapData>(resource_addr), E_SWAP_DATA_NOT_FOUND);
        let swap_data = borrow_global_mut<SwapData>(resource_addr);
        assert!(table::contains(&swap_data.swaps, secret_hash), E_SWAP_NOT_INITIATED);

        let swap = table::borrow_mut(&mut swap_data.swaps, secret_hash);
        assert!(timestamp::now_seconds() >= swap.expiration_time, E_SWAP_NOT_EXPIRED);
        assert!(swap.sender == sender_addr, E_SWAP_NOT_INITIATED);

        coin::transfer<AptosCoin>(&resource_signer, swap.sender, swap.amount);

        table::remove(&mut swap_data.swaps, secret_hash);

        let events = borrow_global_mut<Events>(@play);
        event::emit_event(&mut events.swap_refunded, SwapRefunded { swap_id: secret_hash });
    }
} 