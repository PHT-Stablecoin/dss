#!/usr/bin/env bash

# Read Env
set -a
source .env.sepolia
set +a

# Deploy Setup
forge script ./script/DssProxyDeploy.s.sol:DssProxyDeployScript \
    --rpc-url=$LOCAL_RPC_URL \
    --contracts=./script/ \
    --private-key=$PRIVATE_KEY \
    --broadcast \
    -vvvv