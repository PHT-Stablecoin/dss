#!/usr/bin/env bash

# Read Env
set -a
source .env.development
set +a

# Start Jobs
npx tsx ./script/jobs/runAll.ts