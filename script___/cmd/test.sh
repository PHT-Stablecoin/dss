#!/usr/bin/env bash

# Read Env
set -a
source .env.development
set +a

forge test --skip *.s.sol