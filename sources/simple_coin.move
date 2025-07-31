module play::simple_coin {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::managed_coin;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
    
    struct MyCoin has store, copy, drop {}

    // Custom events for your coin
    struct CoinMintedEvent has drop, store {
        minter: address,
        recipient: address,
        amount: u64,
        timestamp: u64,
    }

    struct CoinBurnedEvent has drop, store {
        burner: address,
        amount: u64,
        timestamp: u64,
    }

    struct CoinTransferredEvent has drop, store {
        from: address,
        to: address,
        amount: u64,
        timestamp: u64,
    }

    // Event handles stored in the module
    struct EventStore has key {
        mint_events: EventHandle<CoinMintedEvent>,
        burn_events: EventHandle<CoinBurnedEvent>,
        transfer_events: EventHandle<CoinTransferredEvent>,
    }

    fun init_module(
        deployer: &signer,
    ) {
        managed_coin::initialize<MyCoin>(deployer, b"Moon Coin", b"MOON", 6, false);
        
        // Initialize event handles
        move_to(deployer, EventStore {
            mint_events: account::new_event_handle<CoinMintedEvent>(deployer),
            burn_events: account::new_event_handle<CoinBurnedEvent>(deployer),
            transfer_events: account::new_event_handle<CoinTransferredEvent>(deployer),
        });
    }

    public entry fun register(account: &signer) {
        managed_coin::register<MyCoin>(account);
    }

    public entry fun mint(
        account: &signer, recipient: address, amount: u64
    ) acquires EventStore {
        managed_coin::mint<MyCoin>(account, recipient, amount);
        
        // Emit custom mint event
        let event_store = borrow_global_mut<EventStore>(@play);
        event::emit_event(&mut event_store.mint_events, CoinMintedEvent {
            minter: signer::address_of(account),
            recipient,
            amount,
            timestamp: timestamp::now_seconds(),
        });
    }

    // New function to burn coins
    public entry fun burn(
        account: &signer, amount: u64
    ) acquires EventStore {
        managed_coin::burn<MyCoin>(account, amount);
        
        // Emit custom burn event
        let event_store = borrow_global_mut<EventStore>(@play);
        event::emit_event(&mut event_store.burn_events, CoinBurnedEvent {
            burner: signer::address_of(account),
            amount,
            timestamp: timestamp::now_seconds(),
        });
    }

    // New function to transfer coins
    public entry fun transfer(
        from: &signer, to: address, amount: u64
    ) acquires EventStore {
        coin::transfer<MyCoin>(from, to, amount);
        
        // Emit custom transfer event
        let event_store = borrow_global_mut<EventStore>(@play);
        event::emit_event(&mut event_store.transfer_events, CoinTransferredEvent {
            from: signer::address_of(from),
            to,
            amount,
            timestamp: timestamp::now_seconds(),
        });
    }
}
