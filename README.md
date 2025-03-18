# PHT MakerDAO Integration

This project implements a PHP stablecoin system built on MakerDAO's Multi-Collateral Dai (MCD) architecture. It enables the creation of a PHP-denominated stablecoin based on different collateral tokens. Additionally it uses the Circle's FiatToken framework for self-managed collateral tokens and custom Chainlink compatible price feeds.

## Overview

The system extends MakerDAO's core contracts to support PHP-denominated assets with three main components:

1. PHT Integration: Connects PHP tokens to MakerDAO's collateral system
2. FiatToken Integration: Manages PHP stablecoin implementation using Circle's framework
3. Deployment System: Orchestrates system deployment and configuration

## Quick Start

```bash
# this will take a long time even on fast connections
forge install
forge build # this is required
# run tests
forge test
```

## Deploy to local node:

```bash
# start anvil in a separate terminal
anvil

# you need to have done a forge install && forge build before this next step
# deploy to local anvil node using its default public/private key at index 0
forge script ./script/PHTDeployment.s.sol --broadcast --rpc-url http://127.0.0.1:8545 \
--sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## Verifying contracts on Arbiscan

```bash
# deploy and verify on Arbitrum Sepolia
forge script ./script/PHTDeployment.s.sol --sig "run(string)" --sender 0x53118050CC8fC8C6925CdC842b1784dcBa9A4ba9 --account PHT \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --verify --verifier custom --verifier-api-key $ARBISCAN_API_KEY --chain-id 421614 --isolate --slow --broadcast \
"arbitrum_sepolia_dev.json"
```

## Project Structure

```
├── audit/              # Audit related readme
├── fiattoken/          # Circle FiatToken integration
├── pht/                # PHT collateral system
│   ├── factory/        # Price feed factories
│   ├── helpers/        # Utility contracts
│   └── lib/            # Shared libraries
├── script/             # Deployment scripts
└── test/               # Test suites
```

## Deployment

### Deployment Config

All deployment configurations are stored in json files under `./config/` folder.

The `collaterals[x].ilkParams.ilk` is a bytes32 encoded string. You can use cast command as such to convert from string to bytes32 (then assing the output to the `ilk` param):

```sh
❯ cast format-bytes32-string "PHP-A"
0x5048502d41000000000000000000000000000000000000000000000000000000
```

Deploying to Sepolia Staging environment example:

```sh
# without `--slow` this reverts (at least on Sepolia) with `-32000: future transaction tries to replace pending`
# PHTSTG is the label given to a wallet, imported via `cast wallet import "PHTSTG" --interactive`
forge script ./script/PHTDeployment.s.sol \
--sig "run(string)" \
--sender 0xE54813199Df6B33c0261fe9CD6eF4Efe660F13FB \
--account PHTSTG \
--broadcast \
--rpc-url $SEPOLIA_RPC_URL \
--verify --isolate --slow \
"sepolia_staging.json"

```

See [./config/tests.json](./config/tests.json) for an example.

## Acknowledgments

This project builds upon:

- [MakerDAO's DSS System](https://github.com/makerdao/dss)
- [Circle's FiatToken](https://github.com/circlefin/stablecoin-evm)
