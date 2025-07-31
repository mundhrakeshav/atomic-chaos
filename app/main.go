package main

import (
	"fmt"
	"log"
	"os"

	"github.com/aptos-labs/aptos-go-sdk"
	"github.com/aptos-labs/aptos-go-sdk/crypto"
)

func main() {
	privateKey := &crypto.Ed25519PrivateKey{}
	privateKeyHex := os.Getenv("PVT_KEY")
	err := privateKey.FromHex(privateKeyHex)
	if err != nil {
		panic("Failed to parse private key:" + err.Error())
	}

	signer, err := aptos.NewAccountFromSigner(privateKey)
	if err != nil {
		log.Fatal(err)
	}

	client, err := aptos.NewClient(aptos.LocalnetConfig)
	if err != nil {
		log.Fatalf("Failed to create client %s", err)
	}

	info, err := client.Info()
	if err != nil {
		log.Fatalf("Failed to get chain info %s", err)
	}

	log.Printf("ChainId: %d", info.ChainId)

	moduleAddress, err := aptos.ConvertToAddress("0x1cce31ab18c8f81e92c0aa3c26a6a1fc7a5bbbda50f80c4f1ad7d3e9eb04242d")
	if err != nil {
		log.Fatalf("failed to parse module address: %s", err)
	}

	log.Printf("Module address: %s", moduleAddress)

	amount := uint64(100)

	entryFunction, err := client.EntryFunctionWithArgs(
		*moduleAddress,
		"simple_coin",
		"mint",
		[]any{},
		[]any{
			moduleAddress,
			amount,
		},
	)
	if err != nil {
		log.Fatalf("could not create entry function: %s", err)
	}
	payload := &aptos.TransactionPayload{
		Payload: entryFunction,
	}

	log.Println("Building transaction...")
	txn, err := client.BuildTransaction(signer.Address, *payload)
	if err != nil {
		log.Fatalf("Failed to build transaction: %s", err)
	}

	log.Println("Transaction built successfully", txn)

	log.Println("Signing transaction...")
	signed, err := txn.SignedTransaction(signer)
	if err != nil {
		log.Fatalf("Failed to sign transaction: %s", err)
	}

	log.Println("Transaction signed successfully", signed)

	submitted, err := client.SubmitTransaction(signed)
	if err != nil {
		log.Fatalf("Failed to submit transaction: %s", err)
	}

	log.Println("Transaction submitted successfully", submitted)

	txnHash := submitted.Hash
	txnRs, err := client.WaitForTransaction(txnHash)
	if err != nil {
		log.Fatalf("Failed to wait for transaction: %s", err)
	}

	log.Println("Transaction committed successfully", txnRs)

	log.Println("Transaction response", txnRs.Success, txnRs.Hash, txnRs.VmStatus)

	// --- Check the balance ---
	log.Println("Checking balance...")

	// The coin type for our simple_coin, which is needed for the generic `balance` function
	myCoinTypeTag := aptos.TypeTag{
		Value: &aptos.StructTag{
			Address:    *moduleAddress,
			Module:     "simple_coin",
			Name:       "MyCoin",
			TypeParams: []aptos.TypeTag{},
		},
	}

	// The address we want to check the balance of.
	// Here, we check the balance of the module owner's account.
	accountToView := *moduleAddress

	// Prepare the ViewPayload to call 0x1::coin::balance<MyCoin>(account_address)
	payloadView := &aptos.ViewPayload{
		Module: aptos.ModuleId{
			Address: aptos.AccountOne, // The `coin` module is at 0x1
			Name:    "coin",
		},
		Function: "balance",
		ArgTypes: []aptos.TypeTag{myCoinTypeTag}, // Specify the coin type here
		Args:     [][]byte{accountToView[:]},    // The account to check
	}

	// Call the view function
	vals, err := client.View(payloadView)
	if err != nil {
		log.Fatalf("Failed to call view function: %s", err)
	}

	// The result is []any, with the first element being the balance
	if len(vals) > 0 {
		balance := vals[0].(string) // The balance is returned as a string
		fmt.Printf("Balance for %s: %s\n", accountToView.String(), balance)
	} else {
		log.Println("View function did not return any values.")
	}
	
	payloadDecimalsView := &aptos.ViewPayload{
		Module: aptos.ModuleId{
			Address: aptos.AccountOne, // The `coin` module is at 0x1
			Name:    "coin",
		},
		Function: "decimals",
		ArgTypes: []aptos.TypeTag{myCoinTypeTag}, // Specify the coin type here
		Args:     [][]byte{},
	}

	// Call the view function
	decimalVals, err := client.View(payloadDecimalsView)
	if err != nil {
		log.Fatalf("Failed to call view function for decimals: %s", err)
	}

	// The result is []any, with the first element being the decimals
	if len(decimalVals) > 0 {
		decimals := decimalVals[0].(float64) // The decimals are returned as a string
		fmt.Printf("Decimals for MyCoin: %f\n", decimals)
	} else {
		log.Println("View function for decimals did not return any values.")
	}

	events, err := client.EventsByCreationNumber(signer.Address, "124", nil, nil)
	if err != nil {
		log.Fatalf("Failed to get events: %s", err)
	}
	log.Println("Events", events)

}


