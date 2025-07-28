module play::message {
    use std::string;
    use std::signer;
    use std::aptos_hash;
    use std::debug;

    struct MessageHolder has key, store, drop {
        message: string::String,
    }

    // public fun greeting():String {
    //     let greet:String = utf8(b"Welcome to Aptos Move by Example");
    //     return greet
    // }


    /// Sets a message for the given account.
    /// This function can be called by anyone to write a message to their own account.
    /// If a message already exists for the account, it will be overwritten.
    public entry fun set_message(account: &signer, message: string::String) acquires MessageHolder {
        let account_addr = signer::address_of(account);

        if (exists<MessageHolder>(account_addr)) {
            move_from<MessageHolder>(account_addr);
        };

        move_to(account, MessageHolder { message });
    }

    /// Retrieves the message for a given account address.
    /// This is a read-only view function.
    /// It will abort if no message is found for the address.
    /// Note: This function also computes and prints the Keccak256 hash of the message for debugging purposes.
    #[view]
    public fun get_message(account_addr: address): string::String acquires MessageHolder {
        assert!(exists<MessageHolder>(account_addr), 0);
        let message_holder = borrow_global<MessageHolder>(account_addr);
        let msg_as_bytes = string::bytes(&message_holder.message);
        let h = aptos_hash::keccak256(*msg_as_bytes);
        debug::print(&h);
        message_holder.message
    }
}