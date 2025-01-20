#!/usr/bin/env bash

# INFURA_RPC_URL=https://mainnet.infura.io/v3/633fd97149b94bf69b4c6f7e35374bf5
# ALCHEMY_MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/zOMxizCXlNBqlBjRrlr9yhSpkWvHVB4n

# Read Env
set -a
source .env.sepolia
set +a

cast send 0x295E277D189Ce7Fe06A7C6EcBe1395A5Fd484B97 --rpc-url $SEPOLIA_RPC_URL \
        --private-key=$PRIVATE_KEY \
        "mint(uint256)" 900000000