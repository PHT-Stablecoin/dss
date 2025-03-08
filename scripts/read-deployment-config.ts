import { ethers, network } from "hardhat";
import * as fs from "fs";
import * as path from "path";

// Define deployment configuration type
interface DeploymentConfig {
  vat: string;
  [key: string]: string;
}

// Function to read deployment configuration
async function getDeploymentConfig(): Promise<DeploymentConfig> {
  const networkId = network.config.chainId;
  let configPath: string;

  // Determine which configuration file to use based on the network
  if (networkId === 1) {
    // Mainnet
    configPath = path.resolve(
      __dirname,
      "../script/output/1/dssDeploy.artifacts.mainnet.json"
    );
    console.log("Using mainnet deployment configuration");
  } else if (networkId === 11155111) {
    // Sepolia (staging)
    configPath = path.resolve(
      __dirname,
      "../script/output/11155111/dssDeploy.artifacts.sepolia_staging.json"
    );
    console.log("Using Sepolia staging deployment configuration");
  } else {
    throw new Error(
      `Network ${network.name} (chainId: ${networkId}) is not supported. Only mainnet and Sepolia staging are supported.`
    );
  }

  // Check if the configuration file exists
  if (!fs.existsSync(configPath)) {
    throw new Error(`Deployment configuration file not found at ${configPath}`);
  }

  // Read and parse the configuration file
  const configContent = fs.readFileSync(configPath, "utf8");
  const config = JSON.parse(configContent) as DeploymentConfig;

  return config;
}

async function main() {
  console.log(
    `Reading deployment configuration for network: ${network.name} (chainId: ${network.config.chainId})`
  );

  try {
    const deploymentConfig = await getDeploymentConfig();

    // Output the vat value
    console.log(
      `Vat address from deployment configuration: ${deploymentConfig.vat}`
    );

    // Output other useful information
    console.log("\nOther useful addresses from the configuration:");
    console.log(`Authority: ${deploymentConfig.authority}`);
    console.log(`DAI: ${deploymentConfig.dai}`);
    console.log(`Pause: ${deploymentConfig.pause}`);
  } catch (error) {
    console.error("Error reading deployment configuration:", error);
    process.exit(1);
  }
}

// Execute the script
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("Script failed:", error);
      process.exit(1);
    });
}

export { getDeploymentConfig };
