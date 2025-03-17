#!/usr/bin/env bash

# Read Env
set -a
source .env
set +a

forge script ./script/migrations/01_migration_issue_29+30.s.sol \
    --private-key=$PRIVATE_KEY \
    --rpc-url=$MAINNET_RPC_URL \
    --verify --isolate --slow \
    --sig="run(string)" "mainnet.json"
