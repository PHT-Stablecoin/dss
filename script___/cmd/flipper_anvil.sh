#!/usr/bin/env bash

# Read Env
set -a
source .env.development
set +a

# Read Artifacts Json
RPC_PORT=8545
ARTIFACT_PATH="$(pwd)/script/output/31337/dssDeploy.artifacts.json"
FLIPPER_ADDRESS=$(npx -y node-jq -r '.ethFlip' $ARTIFACT_PATH)
CAT_ADDRESS=$(npx -y node-jq -r '.cat' $ARTIFACT_PATH)
MODEL_PATH="$(pwd)/auction_models/flipper.sh"
# ETH_KEY_PATH=

# Run Flipper
docker run -it -v "$(pwd)/" makerdao/auction-keeper \
    /opt/keeper/auction-keeper/bin/auction-keeper \
    --rpc-host=$LOCAL_RPC_URL \
    --eth-from=$${PRIVATE_KEY} \
    --eth-key='key_file=/home/keeper/hush/auction.json,pass_file=/home/keeper/hush/auction.pass' \
    --flipper=$FLIPPER_ADDRESS \
    --cat=$CAT_ADDRESS \
    --model=$${MODEL_PATH}