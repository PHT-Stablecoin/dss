# Scripts

This directory contains various scripts for deployment, verification, and other utilities.

## ProxyInitializer Deployment

The `deploy-proxy-initializer.ts` script allows you to deploy and verify the `ProxyInitializer` smart contract on the blockchain.

### Usage

1. Make sure your environment variables are set up correctly in the `.env` file. You'll need:

   - `ETHERSCAN_API_KEY`: For contract verification
   - Network RPC URL (e.g., `MAINNET_RPC_URL`, `GOERLI_RPC_URL`, etc.)
   - Private key for deployment (e.g., `PRIVATE_KEY`)

2. Run the deployment script for your desired network:

```bash
# Deploy on mainnet
npx hardhat run scripts/deploy-proxy-initializer.ts --network mainnet

# Deploy on testnet
npx hardhat run scripts/deploy-proxy-initializer.ts --network goerli

# Deploy locally
npx hardhat run scripts/deploy-proxy-initializer.ts --network localhost
```

3. The script will:
   - Deploy the ProxyInitializer contract
   - Wait for deployment confirmation
   - Verify the contract on Etherscan (if deployed to a public network)
   - Log the contract address for future reference

### Notes

- The ProxyInitializer contract doesn't have any constructor arguments.
- Contract verification requires an Etherscan API key.
- You may need to adjust the path in the verification section if your contract directory structure changes.
