module play::message {
    use std::string;
    use std::signer;

    struct MessageHolder has key, store, drop {
        message: string::String
    }

    public entry fun set_message(
        account: &signer, message: string::String
    ) acquires MessageHolder {
        let account_addr = signer::address_of(account);

        if (exists<MessageHolder>(account_addr)) {
            move_from<MessageHolder>(account_addr);
        };

        move_to(account, MessageHolder { message });
    }

    #[view]
    public fun get_message(account_addr: address): string::String acquires MessageHolder {
        assert!(exists<MessageHolder>(account_addr), 0);
        let message_holder = borrow_global<MessageHolder>(account_addr);
        message_holder.message
    }
}
