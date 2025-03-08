# PHT Contracts Deployment

This script deploys and verifies the `FiatTokenFactory` and `PHTCollateralHelper` smart contracts, including all their dependencies.

## Prerequisites

1. Ensure you have the necessary environment variables in your `.env` file:

   ```
   ETHERSCAN_API_KEY=your_etherscan_api_key
   MAINNET_RPC_URL=your_mainnet_rpc_url
   SEPOLIA_RPC_URL=your_sepolia_rpc_url
   PRIVATE_KEY=your_private_key_without_0x_prefix
   ```

2. Make sure the broadcast files from previous Forge deployments are available at:
   - Mainnet: `broadcast/PHTDeployment.s.sol/1/run-latest.json`
   - Sepolia: `broadcast/PHTDeployment.s.sol/11155111/run-latest.json`

## Usage

Deploy on Sepolia testnet:

```bash
npx hardhat run scripts/deploy-pht-contracts.ts --network sepolia
```

Deploy on Mainnet:

```bash
npx hardhat run scripts/deploy-pht-contracts.ts --network mainnet
```

## What the Script Does

1. **Deploys FiatTokenFactory and its dependencies:**

   - ProxyInitializer
   - ImplementationDeployer
   - MasterMinterDeployer
   - FiatTokenFactory

2. **Fetches required addresses from Forge broadcast file:**

   - Vat
   - Spotter
   - Dog
   - Vow
   - Jug
   - End
   - ESM
   - DSPause

3. **Deploys PHTCollateralHelper and its dependencies:**

   - CalcFab
   - ClipFab
   - GemJoinFab
   - GemJoin5Fab
   - PHTCollateralHelper

4. **Configures permissions:**

   - Sets fabs on PHTCollateralHelper
   - Grants permissions to PHTCollateralHelper on critical contracts (Vat, Spotter, Dog, Jug)

5. **Verifies all deployed contracts on Etherscan**

## Output

The script outputs the addresses of all deployed contracts to the console and returns them in an object that can be used programmatically if the deployment function is imported by another script.
