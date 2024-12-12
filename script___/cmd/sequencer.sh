#!/bin/sh

echo "Starting sequencer cron..."

npx ts-node -r dotenv/config ./script/jobs/sequencer.ts