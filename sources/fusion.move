module play::fusion {
    use std::signer;
    use std::aptos_hash;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use std::table::{Self, Table};
    use aptos_framework::account;


    // The swap has already been initiated.
    const E_SWAP_ALREADY_INITIATED: u64 = 1;
    // The swap has not yet been initiated.
    const E_SWAP_NOT_INITIATED: u64 = 2;
    // The secret provided is incorrect.
    const E_INCORRECT_SECRET: u64 = 3;
    // The swap has not yet expired.
    const E_SWAP_NOT_EXPIRED: u64 = 4;
    // The fusion store already exists for the sender.
    const E_FUSION_STORE_ALREADY_EXISTS: u64 = 5;
    // The fusion store does not exist for the sender.
    const E_FUSION_STORE_NOT_FOUND: u64 = 6;
    // The swap data resource account does not exist.
    const E_SWAP_DATA_NOT_FOUND: u64 = 7;
    // The sender of the swap is incorrect.
    const E_INCORRECT_SENDER: u64 = 8;
    // The recipient of the swap is incorrect.
    const E_INCORRECT_RECIPIENT: u64 = 9;

    // A resource to hold the signer capability for a resource account.
    // This is stored on the user's account to allow them to manage the resource account.
    struct FusionStore has key {
        signer_cap: account::SignerCapability,
    }

    // The data for a single atomic swap.
    // This is stored inside the `SwapData` table.
    struct Swap has store, drop {
        sender: address,
        recipient: address,
        amount: u64,
        chain_id: u64,
        dst_chain_id: u64,
        dst_address: address,
        secret_hash: vector<u8>,
        expiration_time: u64,
    }
    
    // A resource to hold the table of active swaps.
    // This is stored on the resource account created for the `FusionStore`.
    struct SwapData has key {
        swaps: Table<vector<u8>, Swap>,
    }




    #[event]
    // Event emitted when a new swap is initiated.
    struct SwapInitiated has drop, store {
        swap_id: vector<u8>,
        sender: address,
        recipient: address,
        amount: u64,
        chain_id: u64,
        expiration_time: u64,
    }

    #[event]
    // Event emitted when a swap is successfully claimed.
    struct SwapClaimed has drop, store {
        swap_id: vector<u8>,
    }

    #[event]
    // Event emitted when a swap is refunded.
    struct SwapRefunded has drop, store {
        swap_id: vector<u8>,
    }



    // Creates the `FusionStore` for the sender, which holds the signer capability
    // for a new resource account. It also creates and publishes the `SwapData`
    // resource on this new resource account.
    public entry fun init_fusion_store(sender: &signer) {
        let sender_addr = signer::address_of(sender);
        assert!(!exists<FusionStore>(sender_addr), E_FUSION_STORE_ALREADY_EXISTS);
        
        // Create a resource account with a unique seed.
        let (resource_signer, resource_cap) = account::create_resource_account(sender, b"fusion_store");
        let fusion_store = FusionStore { signer_cap: resource_cap };
        move_to(sender, fusion_store);

        // Publish the SwapData table on the newly created resource account.
        let swap_data = SwapData { swaps: table::new() };
        move_to(&resource_signer, swap_data);
    }
    
    // Initiates a new atomic swap. The sender provides the funds and a secret hash.
    // The funds are held in the contract's resource account until the swap is
    // either claimed or refunded.
    public entry fun initiate_swap(
        sender: &signer,
        recipient: address,
        amount: u64,
        chain_id: u64,
        dst_chain_id: u64,
        dst_address: address,
        secret_hash: vector<u8>,
        expiration_time: u64,
    ) acquires FusionStore, SwapData {
        let sender_addr = signer::address_of(sender);

        assert!(exists<FusionStore>(sender_addr), E_FUSION_STORE_NOT_FOUND);

        let fusion_store = borrow_global<FusionStore>(sender_addr);
        let resource_signer = account::create_signer_with_capability(&fusion_store.signer_cap);
        let resource_addr = signer::address_of(&resource_signer);

        assert!(exists<SwapData>(resource_addr), E_SWAP_DATA_NOT_FOUND);

        let swap_data = borrow_global_mut<SwapData>(resource_addr);
        assert!(!table::contains(&swap_data.swaps, secret_hash), E_SWAP_ALREADY_INITIATED);

        // Transfer funds from the sender to the resource account.
        coin::transfer<AptosCoin>(sender, resource_addr, amount);

        // Store the swap data.
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

        // Emit an event to signal the swap initiation.
        event::emit(SwapInitiated {
            swap_id: secret_hash,
            sender: sender_addr,
            recipient,
            amount,
            chain_id,
            expiration_time,
        });
    }

    // Allows the recipient to claim the swap using the secret.
    // The secret is hashed and checked against the stored `secret_hash`.
    public entry fun claim_swap(
        recipient: &signer,
        sender_addr: address,
        secret: vector<u8>,
    ) acquires FusionStore, SwapData {
        let recipient_addr = signer::address_of(recipient);
        assert!(exists<FusionStore>(sender_addr), E_FUSION_STORE_NOT_FOUND);
        let fusion_store = borrow_global<FusionStore>(sender_addr);
        let resource_signer = account::create_signer_with_capability(&fusion_store.signer_cap);
        let resource_addr = signer::address_of(&resource_signer);

        assert!(exists<SwapData>(resource_addr), E_SWAP_DATA_NOT_FOUND);
        let swap_data = borrow_global_mut<SwapData>(resource_addr);
        let secret_hash = aptos_hash::keccak256(secret);

        assert!(table::contains(&swap_data.swaps, secret_hash), E_SWAP_NOT_INITIATED);

        let swap = table::borrow_mut(&mut swap_data.swaps, secret_hash);

        // Ensure the recipient is the correct one.
        assert!(swap.recipient == recipient_addr, E_INCORRECT_RECIPIENT);
        
        // Transfer the held funds to the recipient.
        coin::transfer<AptosCoin>(&resource_signer, recipient_addr, swap.amount);

        // Remove the swap from the table.
        table::remove(&mut swap_data.swaps, secret_hash);
        
        // Emit an event to signal the swap claim.
        event::emit(SwapClaimed { swap_id: secret_hash });
    }

    // Allows the original sender to refund the swap after the expiration time has passed.
    public entry fun refund_swap(
        sender: &signer,
        secret_hash: vector<u8>,
    ) acquires FusionStore, SwapData {
        let sender_addr = signer::address_of(sender);
        assert!(exists<FusionStore>(sender_addr), E_FUSION_STORE_NOT_FOUND);
        let fusion_store = borrow_global<FusionStore>(sender_addr);
        let resource_signer = account::create_signer_with_capability(&fusion_store.signer_cap);
        let resource_addr = signer::address_of(&resource_signer);

        assert!(exists<SwapData>(resource_addr), E_SWAP_DATA_NOT_FOUND);
        let swap_data = borrow_global_mut<SwapData>(resource_addr);
        assert!(table::contains(&swap_data.swaps, secret_hash), E_SWAP_NOT_INITIATED);

        let swap = table::borrow_mut(&mut swap_data.swaps, secret_hash);
        
        // Ensure the expiration time has passed.
        assert!(timestamp::now_seconds() >= swap.expiration_time, E_SWAP_NOT_EXPIRED);
        
        // Ensure the refund is requested by the original sender.
        assert!(swap.sender == sender_addr, E_INCORRECT_SENDER);

        // Transfer funds back to the sender.
        coin::transfer<AptosCoin>(&resource_signer, swap.sender, swap.amount);

        // Remove the swap from the table.
        table::remove(&mut swap_data.swaps, secret_hash);

        // Emit an event to signal the refund.
        event::emit(SwapRefunded { swap_id: secret_hash });
    }

    public fun has_fusion_store(addr: address): bool {
        exists<FusionStore>(addr)
    }
}