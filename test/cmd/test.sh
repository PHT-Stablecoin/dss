# Read Env
set -a
source .env.development
set +a

forge test -vvvvvv