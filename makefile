.PHONY: start-node compile-dev test-dev publish-dev clean-dev get_by_hash run view

# Default values
NETWORK ?= localnet
FAUCET_URL ?= http://127.0.0.1:8081

# Set NODE_URL and network flags based on NETWORK. This logic must be outside any target.
ifeq ($(NETWORK),localnet)
NODE_URL=http://127.0.0.1:8080
else ifeq ($(NETWORK),devnet)
NODE_URL=https://fullnode.devnet.aptoslabs.com/v1
else ifeq ($(NETWORK),testnet)
NODE_URL=https://fullnode.testnet.aptoslabs.com/v1
else ifeq ($(NETWORK),mainnet)
NODE_URL=https://fullnode.mainnet.aptoslabs.com/v1
endif

start-node:
	aptos node run-localnet --with-indexer-api --with-faucet --force-restart

compile-dev:
	aptos move compile --dev

test-dev:
	aptos move test --dev

publish-dev:
	aptos move publish --assume-yes --dev --max-gas 2000000 --url $(NODE_URL)


fund-dev:
	@if [ -z "$(ACCOUNT)" ] || [ -z "$(AMOUNT)" ]; then \
		echo "Error: ACCOUNT and AMOUNT must be set." >&2; \
		echo "Usage: make fund-dev ACCOUNT=<profile_or_addr> AMOUNT=<amount>" >&2; \
		exit 1; \
	fi
	aptos account fund-with-faucet --account $(ACCOUNT) --amount $(AMOUNT) --faucet-url $(FAUCET_URL)

clean:
	rm -rf ./build

lint-dev:
	aptos move lint --dev

get_by_hash:
	@if [ "$(TXN_HASH)" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then \
		echo "Error: A valid transaction hash must be provided via TXN_HASH" >&2; \
		exit 1; \
	fi
	@echo "Fetching transaction from $(NETWORK) with hash $(TXN_HASH)"
	@if [ -z "$(NODE_URL)" ]; then \
		echo "Error: Could not determine API URL. Is NETWORK set correctly? ($(NETWORK))" >&2; \
		exit 1; \
	fi
	@CLEAN_HASH=$$(echo "$(TXN_HASH)" | sed 's/0x//'); \
	if ! echo "$$CLEAN_HASH" | grep -qE '^[0-9a-fA-F]{64}$$'; then \
		echo "Error: Invalid TXN_HASH format. It must be a 64-character hexadecimal string, optionally prefixed with 0x." >&2; \
		exit 1; \
	fi
	@curl -s "$(NODE_URL)/v1/transactions/by_hash/$(TXN_HASH)" | jq

run:
	@if [ -z "$(ACCOUNT)" ] || [ -z "$(MODULE)" ] || [ -z "$(FUNCTION)" ]; then \
		echo "Error: ACCOUNT, MODULE, and FUNCTION must be set." >&2; \
		echo "Usage: make run ACCOUNT=<profile_or_addr> MODULE=<module_name> FUNCTION=<function_name> [ARGS='<args>']" >&2; \
		exit 1; \
	fi
	@echo "Executing function [$(FUNCTION)] in module [$(MODULE)] at account [$(ACCOUNT)] with args [$(ARGS)]"
	@if [ -z "$(ARGS)" ]; then \
		aptos move run --function-id "$(ACCOUNT)::$(MODULE)::$(FUNCTION)" --assume-yes $(NETWORK_FLAG); \
	else \
		aptos move run --function-id "$(ACCOUNT)::$(MODULE)::$(FUNCTION)" --args $(ARGS) --assume-yes $(NETWORK_FLAG); \
	fi

view:
	@if [ -z "$(ACCOUNT)" ] || [ -z "$(MODULE)" ] || [ -z "$(FUNCTION)" ]; then \
		echo "Error: ACCOUNT, MODULE, and FUNCTION must be set." >&2; \
		echo "Usage: make view ACCOUNT=<profile_or_addr> MODULE=<module_name> FUNCTION=<function_name> [ARGS='<args>']" >&2; \
		exit 1; \
	fi
	@echo "Viewing function [$(FUNCTION)] in module [$(MODULE)] at account [$(ACCOUNT)] with args [$(ARGS)]"
	@if [ -z "$(ARGS)" ]; then \
		aptos move view --function-id "$(ACCOUNT)::$(MODULE)::$(FUNCTION)" $(NETWORK_FLAG); \
	else \
		aptos move view --function-id "$(ACCOUNT)::$(MODULE)::$(FUNCTION)" --args $(ARGS) $(NETWORK_FLAG); \
	fi

node:
	aptos node run-localnet --with-indexer-api --with-faucet --force-restart