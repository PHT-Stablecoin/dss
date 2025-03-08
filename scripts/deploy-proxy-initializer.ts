import { ethers, network, run } from "hardhat";
import { getDeploymentConfig } from "./read-deployment-config";

async function main() {
  console.log("Starting ProxyInitializer deployment and verification...");
  console.log(`Network: ${network.name} (chainId: ${network.config.chainId})`);

  // Read deployment configuration
  console.log("Reading deployment configuration...");
  const deploymentConfig = await getDeploymentConfig();

  // Output the vat value as requested
  console.log(
    `Vat address from deployment configuration: ${deploymentConfig.vat}`
  );

  // Get the deployer account with better error handling
  console.log("Getting deployer account...");
  const signers = await ethers.getSigners();

  if (!signers || signers.length === 0) {
    throw new Error(
      "No signers available. Make sure your network configuration is correct and that a private key is provided if needed."
    );
  }

  const deployer = signers[0];
  if (!deployer) {
    throw new Error("Failed to get deployer account.");
  }

  const deployerAddress = await deployer.getAddress();
  console.log(`Deploying with account: ${deployerAddress}`);

  // Deploy the ProxyInitializer contract
  console.log("Compiling and deploying ProxyInitializer...");
  const ProxyInitializer = await ethers.getContractFactory("ProxyInitializer");
  const proxyInitializer = await ProxyInitializer.deploy();

  // Wait for deployment to finish
  const deployTx = await proxyInitializer.waitForDeployment();
  const proxyInitializerAddress = await proxyInitializer.getAddress();
  console.log(`ProxyInitializer deployed to: ${proxyInitializerAddress}`);

  // Wait for a few block confirmations to ensure the contract is deployed
  console.log("Waiting for block confirmations...");
  const deploymentTransaction = proxyInitializer.deploymentTransaction();
  if (deploymentTransaction) {
    await deploymentTransaction.wait(5);
  }

  // Verify the contract on Etherscan
  console.log("Verifying contract on Etherscan...");
  try {
    await run("verify:verify", {
      address: proxyInitializerAddress,
      constructorArguments: [],
      contract: "fiattoken/ProxyInitializer.sol:ProxyInitializer",
    });
    console.log("ProxyInitializer verified successfully!");
  } catch (error) {
    console.error("Error verifying contract:", error);
  }

  console.log("Deployment and verification completed.");

  // Return the contract instance and address for testing or further use
  return { proxyInitializer, address: proxyInitializerAddress };
}

// Execute the deployment
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("Deployment failed:", error);
      process.exit(1);
    });
}

// Export for testing
export { main as deployProxyInitializer };
