#!/usr/bin/env bash

# INFURA_RPC_URL=https://mainnet.infura.io/v3/633fd97149b94bf69b4c6f7e35374bf5
# ALCHEMY_MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/zOMxizCXlNBqlBjRrlr9yhSpkWvHVB4n

# Read Env
set -a
source .env.development
set +a

# Deploy Setup
# forge debug ./script/DssJobsDeploy.s.sol:DssJobsDeployScript \
#     --rpc-url=$LOCAL_RPC_URL \
#     --contracts=./script/ \
#     -- --private-key=$PRIVATE_KEY \
#     # --broadcast
forge script ./script/DssJobsDeploy.s.sol:DssJobsDeployScript \
    --rpc-url=$LOCAL_RPC_URL \
    --contracts=./script/ \
    --private-key=$PRIVATE_KEY \
    --broadcast


    