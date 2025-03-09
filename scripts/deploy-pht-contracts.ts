import { ethers, network, run } from "hardhat";
import { getContractAddressFromBroadcast } from "./utils/forge-utils";
import { getDeploymentConfig } from "./read-deployment-config";
import * as fs from "fs";
import * as path from "path";
import { execSync } from "child_process";

// Define the structure of system addresses needed for deployment
interface SystemAddresses {
  vat: string;
  spotter: string;
  dog: string;
  vow: string;
  jug: string;
  end: string;
  esm: string;
  pause: string;
}

// Mapping of contract names to their keys in the deployment config
const CONTRACT_NAME_MAP: Record<string, string> = {
  Vat: "vat",
  Spotter: "spotter",
  Dog: "dog",
  Vow: "vow",
  Jug: "jug",
  End: "end",
  ESM: "esm",
  DSPause: "pause",
  Cat: "cat",
  Flap: "flap",
  Flop: "flop",
  Pot: "pot",
  DaiJoin: "daiJoin",
  MkrAuthority: "mkrAuthority",
  DSProxyRegistry: "dssProxyRegistry",
  IlkRegistry: "ilkRegistry",
};

// Function to get contract address from deployment config or broadcast file
async function getContractAddress(
  contractName: string,
  deploymentConfig: Record<string, string>
): Promise<string> {
  // Get the config key for this contract name
  const configKey =
    CONTRACT_NAME_MAP[contractName] || contractName.toLowerCase();

  // Try to get from deployment config first
  if (deploymentConfig[configKey]) {
    console.log(
      `Found ${contractName} in deployment config: ${deploymentConfig[configKey]}`
    );
    return deploymentConfig[configKey];
  }

  // Fallback to broadcast file
  try {
    const address = getContractAddressFromBroadcast(contractName);
    console.log(`Found ${contractName} in broadcast file: ${address}`);
    return address;
  } catch (error) {
    throw new Error(
      `Could not find address for ${contractName} in either deployment config or broadcast file`
    );
  }
}

async function deployFiatTokenFactory() {
  console.log("Deploying FiatTokenFactory and dependencies...");

  // First, deploy the SignatureChecker library (needed by ImplementationDeployer)
  console.log("Deploying SignatureChecker library...");
  const SignatureChecker = await ethers.getContractFactory("SignatureChecker");
  const signatureChecker = await SignatureChecker.deploy();
  await signatureChecker.waitForDeployment();
  const signatureCheckerAddress = await signatureChecker.getAddress();
  console.log(
    `SignatureChecker library deployed to: ${signatureCheckerAddress}`
  );

  // Deploy ProxyInitializer first (required by FiatTokenFactory)
  console.log("Deploying ProxyInitializer...");
  const ProxyInitializer = await ethers.getContractFactory("ProxyInitializer");
  const proxyInitializer = await ProxyInitializer.deploy();
  await proxyInitializer.waitForDeployment();
  const proxyInitializerAddress = await proxyInitializer.getAddress();
  console.log(`ProxyInitializer deployed to: ${proxyInitializerAddress}`);

  // Deploy ImplementationDeployer with library linking
  console.log("Deploying ImplementationDeployer...");
  const ImplementationDeployer = await ethers.getContractFactory(
    "ImplementationDeployer",
    {
      libraries: {
        "stablecoin-evm/util/SignatureChecker.sol:SignatureChecker":
          signatureCheckerAddress,
      },
    }
  );
  const implementationDeployer = await ImplementationDeployer.deploy();
  await implementationDeployer.waitForDeployment();
  const implementationDeployerAddress =
    await implementationDeployer.getAddress();
  console.log(
    `ImplementationDeployer deployed to: ${implementationDeployerAddress}`
  );

  // Deploy MasterMinterDeployer
  console.log("Deploying MasterMinterDeployer...");
  const MasterMinterDeployer = await ethers.getContractFactory(
    "MasterMinterDeployer"
  );
  const masterMinterDeployer = await MasterMinterDeployer.deploy();
  await masterMinterDeployer.waitForDeployment();
  const masterMinterDeployerAddress = await masterMinterDeployer.getAddress();
  console.log(
    `MasterMinterDeployer deployed to: ${masterMinterDeployerAddress}`
  );

  // Deploy FiatTokenFactory
  console.log("Deploying FiatTokenFactory...");
  const FiatTokenFactory = await ethers.getContractFactory("FiatTokenFactory");
  const fiatTokenFactory = await FiatTokenFactory.deploy(
    implementationDeployerAddress,
    masterMinterDeployerAddress,
    proxyInitializerAddress
  );
  await fiatTokenFactory.waitForDeployment();
  const fiatTokenFactoryAddress = await fiatTokenFactory.getAddress();
  console.log(`FiatTokenFactory deployed to: ${fiatTokenFactoryAddress}`);

  // Verify contracts if not on local network
  if (network.name !== "localhost" && network.name !== "hardhat") {
    await verifyContract(
      signatureCheckerAddress,
      [],
      "stablecoin-evm/util/SignatureChecker.sol:SignatureChecker"
    );
    await verifyContract(
      proxyInitializerAddress,
      [],
      "fiattoken/ProxyInitializer.sol:ProxyInitializer"
    );

    // Verify ImplementationDeployer with library info
    try {
      console.log(
        `Verifying ImplementationDeployer at ${implementationDeployerAddress}...`
      );
      await run("verify:verify", {
        address: implementationDeployerAddress,
        constructorArguments: [],
        contract: "fiattoken/ImplementationDeployer.sol:ImplementationDeployer",
        libraries: {
          "stablecoin-evm/util/SignatureChecker.sol:SignatureChecker":
            signatureCheckerAddress,
        },
      });
      console.log("ImplementationDeployer verified successfully");
    } catch (error) {
      console.error("Error verifying ImplementationDeployer:", error);
    }

    await verifyContract(
      masterMinterDeployerAddress,
      [],
      "fiattoken/MasterMinterDeployer.sol:MasterMinterDeployer"
    );
    await verifyContract(
      fiatTokenFactoryAddress,
      [
        implementationDeployerAddress,
        masterMinterDeployerAddress,
        proxyInitializerAddress,
      ],
      "fiattoken/FiatTokenFactory.sol:FiatTokenFactory"
    );
  }

  return {
    signatureChecker: signatureCheckerAddress,
    proxyInitializer: proxyInitializerAddress,
    implementationDeployer: implementationDeployerAddress,
    masterMinterDeployer: masterMinterDeployerAddress,
    fiatTokenFactory: fiatTokenFactoryAddress,
  };
}

async function deployPHTTokenHelper(
  fiatTokenFactoryAddress: string,
  pauseAddress: string
) {
  console.log("Deploying PHTTokenHelper and dependencies...");

  // Deploy TokenActions
  console.log("Deploying TokenActions...");
  const TokenActions = await ethers.getContractFactory("TokenActions");
  const tokenActions = await TokenActions.deploy();
  await tokenActions.waitForDeployment();
  const tokenActionsAddress = await tokenActions.getAddress();
  console.log(`TokenActions deployed to: ${tokenActionsAddress}`);

  // Deploy PHTTokenHelper
  console.log("Deploying PHTTokenHelper...");
  const PHTTokenHelper = await ethers.getContractFactory("PHTTokenHelper");
  const phtTokenHelper = await PHTTokenHelper.deploy(
    pauseAddress,
    tokenActionsAddress,
    fiatTokenFactoryAddress
  );
  await phtTokenHelper.waitForDeployment();
  const phtTokenHelperAddress = await phtTokenHelper.getAddress();
  console.log(`PHTTokenHelper deployed to: ${phtTokenHelperAddress}`);

  // Verify contracts
  if (network.name !== "localhost" && network.name !== "hardhat") {
    await verifyContract(
      tokenActionsAddress,
      [],
      "pht/helpers/TokenActions.sol:TokenActions"
    );
    await verifyContract(
      phtTokenHelperAddress,
      [pauseAddress, tokenActionsAddress, fiatTokenFactoryAddress],
      "pht/PHTTokenHelper.sol:PHTTokenHelper"
    );
  }

  return {
    tokenActions: tokenActionsAddress,
    phtTokenHelper: phtTokenHelperAddress,
  };
}

async function deployPHTCollateralHelper(
  fiatTokenFactoryAddress: string,
  addresses: SystemAddresses,
  tokenHelperAddress?: string
) {
  console.log("Deploying PHTCollateralHelper and dependencies...");

  // Deploy required fabs for PHTCollateralHelper
  console.log("Deploying fabs for PHTCollateralHelper...");

  // Deploy CalcFab
  const CalcFab = await ethers.getContractFactory("CalcFab");
  const calcFab = await CalcFab.deploy();
  await calcFab.waitForDeployment();
  const calcFabAddress = await calcFab.getAddress();
  console.log(`CalcFab deployed to: ${calcFabAddress}`);

  // Deploy ClipFab
  const ClipFab = await ethers.getContractFactory("ClipFab");
  const clipFab = await ClipFab.deploy();
  await clipFab.waitForDeployment();
  const clipFabAddress = await clipFab.getAddress();
  console.log(`ClipFab deployed to: ${clipFabAddress}`);

  // Deploy GemJoinFab
  const GemJoinFab = await ethers.getContractFactory("GemJoinFab");
  const gemJoinFab = await GemJoinFab.deploy();
  await gemJoinFab.waitForDeployment();
  const gemJoinFabAddress = await gemJoinFab.getAddress();
  console.log(`GemJoinFab deployed to: ${gemJoinFabAddress}`);

  // Deploy GemJoin5Fab
  const GemJoin5Fab = await ethers.getContractFactory("GemJoin5Fab");
  const gemJoin5Fab = await GemJoin5Fab.deploy();
  await gemJoin5Fab.waitForDeployment();
  const gemJoin5FabAddress = await gemJoin5Fab.getAddress();
  console.log(`GemJoin5Fab deployed to: ${gemJoin5FabAddress}`);

  // Deploy PHTCollateralHelper
  console.log("Deploying PHTCollateralHelper...");
  const PHTCollateralHelper = await ethers.getContractFactory(
    "PHTCollateralHelper"
  );
  const phtCollateralHelper = await PHTCollateralHelper.deploy(
    addresses.vat,
    addresses.spotter,
    addresses.dog,
    addresses.vow,
    addresses.jug,
    addresses.end,
    addresses.esm,
    addresses.pause
  );
  await phtCollateralHelper.waitForDeployment();
  const phtCollateralHelperAddress = await phtCollateralHelper.getAddress();
  console.log(`PHTCollateralHelper deployed to: ${phtCollateralHelperAddress}`);

  // Configure PHTCollateralHelper with fabs
  console.log("Setting fabs for PHTCollateralHelper...");
  const setFabsTx = await phtCollateralHelper.setFabs(
    calcFabAddress,
    clipFabAddress,
    gemJoinFabAddress,
    gemJoin5FabAddress
  );
  await setFabsTx.wait();
  console.log("Fabs set for PHTCollateralHelper");

  // Set TokenHelper if provided
  if (tokenHelperAddress) {
    console.log(
      `Setting TokenHelper for PHTCollateralHelper to ${tokenHelperAddress}...`
    );
    const setTokenHelperTx = await phtCollateralHelper.setTokenHelper(
      tokenHelperAddress
    );
    await setTokenHelperTx.wait();
    console.log("TokenHelper set for PHTCollateralHelper");
  }

  // Configure permissions
  console.log("Configuring permissions...");

  // Get deployed contracts to call methods on them
  const vat = await ethers.getContractAt("Vat", addresses.vat);
  const spotter = await ethers.getContractAt("Spotter", addresses.spotter);
  const dog = await ethers.getContractAt("Dog", addresses.dog);
  const jug = await ethers.getContractAt("Jug", addresses.jug);

  // Rely PHTCollateralHelper on required contracts
  try {
    console.log("Granting permissions to PHTCollateralHelper...");

    // Rely on Vat
    let tx = await vat.rely(phtCollateralHelperAddress);
    await tx.wait();
    console.log("Granted permissions to PHTCollateralHelper on Vat");

    // Rely on Spotter
    tx = await spotter.rely(phtCollateralHelperAddress);
    await tx.wait();
    console.log("Granted permissions to PHTCollateralHelper on Spotter");

    // Rely on Dog
    tx = await dog.rely(phtCollateralHelperAddress);
    await tx.wait();
    console.log("Granted permissions to PHTCollateralHelper on Dog");

    // Rely on Jug
    tx = await jug.rely(phtCollateralHelperAddress);
    await tx.wait();
    console.log("Granted permissions to PHTCollateralHelper on Jug");
  } catch (error) {
    console.error("Error granting permissions:", error);
  }

  // Verify Fabs
  await verifyContract(calcFabAddress, [], "dss-deploy/CalcFab.sol:CalcFab");
  await verifyContract(clipFabAddress, [], "dss-deploy/ClipFab.sol:ClipFab");
  await verifyContract(
    gemJoinFabAddress,
    [],
    "pht/PHTCollateralHelper.sol:GemJoinFab"
  );
  await verifyContract(
    gemJoin5FabAddress,
    [],
    "pht/PHTCollateralHelper.sol:GemJoin5Fab"
  );

  // Verify PHTCollateralHelper
  await verifyContract(
    phtCollateralHelperAddress,
    [
      addresses.vat,
      addresses.spotter,
      addresses.dog,
      addresses.vow,
      addresses.jug,
      addresses.end,
      addresses.esm,
      addresses.pause,
    ],
    "pht/PHTCollateralHelper.sol:PHTCollateralHelper"
  );

  return {
    calcFab: calcFabAddress,
    clipFab: clipFabAddress,
    gemJoinFab: gemJoinFabAddress,
    gemJoin5Fab: gemJoin5FabAddress,
    phtCollateralHelper: phtCollateralHelperAddress,
  };
}

// New function that focuses only on verifying PHTCollateralHelper
async function deployAndVerifyCollateralHelper() {
  console.log(`Deploying and verifying PHTCollateralHelper on ${network.name}`);

  // Fetch deployment configuration
  console.log("Fetching deployment configuration...");
  const deploymentConfig = await getDeploymentConfig();

  // Collect necessary addresses
  console.log("Collecting system addresses...");
  const addresses: SystemAddresses = {
    vat: await getContractAddress("Vat", deploymentConfig),
    spotter: await getContractAddress("Spotter", deploymentConfig),
    dog: await getContractAddress("Dog", deploymentConfig),
    vow: await getContractAddress("Vow", deploymentConfig),
    jug: await getContractAddress("Jug", deploymentConfig),
    end: await getContractAddress("End", deploymentConfig),
    esm: await getContractAddress("ESM", deploymentConfig),
    pause: await getContractAddress("DSPause", deploymentConfig),
  };

  console.log("System addresses:");
  Object.entries(addresses).forEach(([name, address]) => {
    console.log(`${name}: ${address}`);
  });

  // Deploy using the specialized function
  await deployPHTCollateralHelper(
    "", // Empty string for fiatTokenFactoryAddress as we're only deploying the collateral helper
    addresses
  );

  console.log("Completed");
}

async function configureTokenFactoryPermissions(
  fiatTokenFactoryAddress: string,
  pauseAddress: string
) {
  console.log("Configuring FiatTokenFactory permissions...");

  // Get the token factory contract instance
  const fiatTokenFactory = await ethers.getContractAt(
    "FiatTokenFactory",
    fiatTokenFactoryAddress
  );

  // Get the pause proxy address from the pause contract
  const pause = await ethers.getContractAt("DSPause", pauseAddress);
  const pauseProxyAddress = await pause.proxy();
  console.log(`Pause proxy address: ${pauseProxyAddress}`);

  // Grant permissions to pause proxy (equivalent to tokenFactory.rely(address(dssDeploy.pause().proxy())) in Solidity)
  console.log("Granting permissions to pause proxy...");
  const relyTx = await fiatTokenFactory.rely(pauseProxyAddress);
  await relyTx.wait();
  console.log(
    `Granted 'rely' permission to pause proxy at ${pauseProxyAddress}`
  );

  // Remove permissions from deployer (equivalent to tokenFactory.deny(address(this)) in Solidity)
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  console.log("Removing permissions from deployer...");
  const denyTx = await fiatTokenFactory.deny(deployerAddress);
  await denyTx.wait();
  console.log(`Removed 'rely' permission from deployer at ${deployerAddress}`);

  console.log("FiatTokenFactory permissions configured successfully");

  return { pauseProxy: pauseProxyAddress };
}

async function main() {
  console.log(
    `Deploying contracts on ${network.name} (${network.config.chainId})`
  );

  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer address: ${await deployer.getAddress()}`);

  // Fetch deployment configuration first
  console.log("Fetching deployment configuration...");
  const deploymentConfig = await getDeploymentConfig();

  // Collect all the system addresses, falling back to broadcast file if needed
  console.log("Collecting system addresses...");
  const addresses: SystemAddresses = {
    vat: await getContractAddress("Vat", deploymentConfig),
    spotter: await getContractAddress("Spotter", deploymentConfig),
    dog: await getContractAddress("Dog", deploymentConfig),
    vow: await getContractAddress("Vow", deploymentConfig),
    jug: await getContractAddress("Jug", deploymentConfig),
    end: await getContractAddress("End", deploymentConfig),
    esm: await getContractAddress("ESM", deploymentConfig),
    pause: await getContractAddress("DSPause", deploymentConfig),
  };

  console.log("System addresses collected:");
  Object.entries(addresses).forEach(([name, address]) => {
    console.log(`${name}: ${address}`);
  });

  // Step 1: Deploy FiatTokenFactory and its dependencies
  const fiatTokenResult = await deployFiatTokenFactory();

  // Step 2: Configure FiatTokenFactory permissions
  await configureTokenFactoryPermissions(
    fiatTokenResult.fiatTokenFactory,
    addresses.pause
  );

  // Step 3: Deploy PHTTokenHelper
  const tokenHelperResult = await deployPHTTokenHelper(
    fiatTokenResult.fiatTokenFactory,
    addresses.pause
  );

  // Step 4: Deploy PHTCollateralHelper using the FiatTokenFactory address and TokenHelper
  const collateralHelperResult = await deployPHTCollateralHelper(
    fiatTokenResult.fiatTokenFactory,
    addresses,
    tokenHelperResult.phtTokenHelper
  );

  console.log("Deployment and verification completed");
  return {
    ...fiatTokenResult,
    ...tokenHelperResult,
    ...collateralHelperResult,
  };
}

async function verifyContract(
  address: string,
  constructorArguments: any[],
  contract: string
) {
  try {
    console.log(`Verifying ${contract} at ${address}...`);
    await run("verify:verify", {
      address,
      constructorArguments,
      contract,
    });
    console.log(`${contract} verified successfully`);
  } catch (error) {
    console.error(`Error verifying ${contract}:`, error);
  }
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("Deployment failed:", error);
      process.exit(1);
    });
}

export {
  main as deployPHTContracts,
  deployFiatTokenFactory,
  deployPHTCollateralHelper,
  deployAndVerifyCollateralHelper,
  getContractAddress,
  CONTRACT_NAME_MAP,
};
