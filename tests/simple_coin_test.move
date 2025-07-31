#[test_only]
module play::simple_coin_tests {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::managed_coin;
    use aptos_framework::coin;

    use play::simple_coin::{Self, SimpleCoin};

    #[test(admin = @0x123, user = @0x456)]
    fun test_full_flow(admin: &signer, user: &signer) {
        let admin_addr = signer::address_of(admin);
        let user_addr = signer::address_of(user);

        // Create accounts
        account::create_account_for_test(admin_addr);
        account::create_account_for_test(user_addr);

        // Initialize the coin
        simple_coin::initialize(admin, b"Simple Coin", b"SIM", 8);

        // The admin can mint and burn
        managed_coin::register<SimpleCoin>(admin);
        // The user needs to register to receive coins
        coin::register<SimpleCoin>(user);

        // Mint 1000 coins to the admin
        simple_coin::mint(admin, admin_addr, 1000);
        assert!(simple_coin::balance_of(admin_addr) == 1000, 1);
        assert!(simple_coin::total_supply() == 1000, 2);

        // Transfer 100 coins from admin to user
        simple_coin::transfer(admin, user_addr, 100);
        assert!(simple_coin::balance_of(admin_addr) == 900, 3);
        assert!(simple_coin::balance_of(user_addr) == 100, 4);

        // Burn 50 coins from the admin
        simple_coin::burn(admin, 50);
        assert!(simple_coin::balance_of(admin_addr) == 850, 5);
        assert!(simple_coin::total_supply() == 950, 6);
    }
}
