#!/usr/bin/env bash

# Read Env
set -a
source .env.development
set +a

# Read Artifacts Json
RPC_PORT=8545
ARTIFACT_PATH="$(pwd)/script/output/31337/dssProxyDeploy.artifacts.json"
PROXY=$(npx -y node-jq -r '.dssProxy' $ARTIFACT_PATH)
PROXY_OWNER=$(npx -y node-jq -r '.dssProxyOwner' $ARTIFACT_PATH)
PROXY_REGISTRY=$(npx -y node-jq -r '.dssProxyRegistry' $ARTIFACT_PATH)
MODEL_PATH="$(pwd)/auction_models/flipper.sh"

# 1. Create and Setup DS-Proxy
# Get proxy address or create new one
# cast call $PROXY_REGISTRY "proxies(address)(address)" $PUBLIC_KEY
# # If no proxy exists, create one:
# cast send $PROXY_REGISTRY "build()" --private-key $PRIVATE_KEY

# 2. Open PHP-A Vault and Lock PHP
# Calculate PHP amount (e.g., 5000 PHP = 5000000000 because PHP has 6 decimals)
export LOCK_USDC_AMOUNT=5000000000
# Calculate PHT amount in WAD (e.g., 2500 PHT = 2500000000000000000000 because PHT has 18 decimals)
export DRAW_PHT_AMOUNT=2500000000000000000000
