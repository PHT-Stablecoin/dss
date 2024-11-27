import { ethers } from 'ethers';
import cron from 'node-cron';
import dotenv from 'dotenv';
import { readFile } from 'fs/promises';
import path from 'path';

dotenv.config();

const SEQUENCER_ABI = [
  'function getNextJobs(bytes32 network) view returns (tuple(address job, bool canWork, bytes args)[])',
  'function networks(bytes32) view returns (uint256 window, uint256 lastExecuted)',
  'function numJobs() external view returns (uint256)',
  'function jobAt(uint256 index) public view returns (address)',
  'function hasJob(address job) public view returns (bool)',
  'function isMaster(bytes32 network) external view returns (bool)'
];

const JOB_ABI = [
  'function work(bytes32 network, bytes args) external',
  'function workable(bytes32 network) external returns (bool canWork, bytes memory args)'
];

interface SequencerConfig {
  provider: ethers.JsonRpcProvider;
  wallet: ethers.Wallet;
  sequencer: ethers.Contract;
}

interface WorkableJob {
  job: string;
  canWork: boolean;
  args: string;
}

class SequencerCron {
  private provider: ethers.JsonRpcProvider;
  private wallet: ethers.Wallet;
  private sequencer: ethers.Contract;
  private readonly NET_MAIN = ethers.encodeBytes32String('NTWK-MAIN');

  constructor(config: SequencerConfig) {
    this.provider = config.provider;
    this.wallet = config.wallet;
    this.sequencer = config.sequencer;
  }

  private async validateJob(jobAddress: string): Promise<boolean> {
    try {
      const isDeployed = await isContractDeployed(this.provider, jobAddress);
      if (!isDeployed) {
        console.warn(`❌ Job contract not deployed at ${jobAddress}`);
        return false;
      }

      // Check if job is registered in sequencer
      const isRegistered = await this.sequencer.hasJob(jobAddress);
      if (!isRegistered) {
        console.warn(`❌ Job ${jobAddress} is not registered in sequencer`);
        return false;
      }

      console.log(`✅ Job contract verified at ${jobAddress}`);
      return true;
    } catch (error) {
      console.error(`Error validating job at ${jobAddress}:`, error);
      return false;
    }
  }

  private async executeJob(jobAddress: string, args: string): Promise<void> {
    try {
      if (!await this.validateJob(jobAddress)) {
        throw new Error('Job contract validation failed');
      }

      const job = new ethers.Contract(jobAddress, JOB_ABI, this.wallet);

      const isMaster = await this.sequencer.isMaster(this.NET_MAIN);
      if (!isMaster) {
        console.log(`⏳ Network ${ethers.decodeBytes32String(this.NET_MAIN)} is not currently master`);
        return;
      }

      console.log(`Executing job at ${jobAddress}`);

      const tx = await job.work(this.NET_MAIN, args, {
        gasLimit: 1000000, // @todo make this configurable per job
      });

      const receipt = await tx.wait();

      console.log(`✅ Job executed successfully`, {
        jobAddress,
        transactionHash: receipt.hash,
        blockNumber: receipt.blockNumber,
        gasUsed: receipt.gasUsed.toString()
      });
    } catch (error) {
      console.log('❌ Error executing job', {
        jobAddress,
        error: (error as Error).message
      });
    }
  }

  public async checkAndExecuteJobs(): Promise<void> {
    try {
      const balance = await this.provider.getBalance(this.wallet.address);
      console.log('💰 Wallet balance:', ethers.formatEther(balance), 'ETH');

      const networkId = ethers.decodeBytes32String(this.NET_MAIN);
      console.log('🔍 Fetching jobs for network:', networkId);

      // Check if we are master
      const isMaster = await this.sequencer.isMaster(this.NET_MAIN);
      console.log(`🌐 Network ${networkId} master status:`, isMaster);

      const jobs: WorkableJob[] = await this.sequencer.getNextJobs(this.NET_MAIN);
      console.log(`📋 Found ${jobs.length} jobs`);

      for (const job of jobs) {
        if (job.canWork) {
          console.log(`✨ Found workable job`, {
            jobAddress: job.job,
            args: job.args
          });

          await this.executeJob(job.job, job.args);
        } else {
          console.debug(`⏳ Job not workable`, {
            jobAddress: job.job
          });
        }
      }
    } catch (error) {
      console.error('❌ Error checking jobs', {
        error: (error as Error).message,
        stack: (error as Error).stack
      });
    }
  }
}

const startCron = async () => {
  const config = await loadConfig();
  const sequencerCron = new SequencerCron(config);

  // Run every minute
  cron.schedule('* * * * *', async () => {
    await sequencerCron.checkAndExecuteJobs();
  }, { runOnInit: true });

  console.log('Sequencer cron job started');
};

async function isContractDeployed(provider: ethers.Provider, address: string): Promise<boolean> {
  const code = await provider.getCode(address);
  return code !== '0x';
}

async function loadConfig(): Promise<SequencerConfig> {
  try {
    if (!process.env.LOCAL_RPC_URL) throw new Error('LOCAL_RPC_URL not set');
    if (!process.env.PRIVATE_KEY) throw new Error('PRIVATE_KEY not set');

    // Initialize provider with retry options
    const provider = new ethers.JsonRpcProvider(process.env.LOCAL_RPC_URL);

    // Get network to ensure connection
    const network = await provider.getNetwork();
    console.log('Connected to network:', {
      chainId: network.chainId,
      name: network.name
    });

    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

    // Read deployment artifacts
    const artifactsPath = path.resolve(
      __dirname,              // Current directory (script/jobs)
      '..',                   // Up one level (script)
      'output',               // Into output directory
      network.chainId.toString(),  // Chain ID directory
      'dssJobsDeploy.artifacts.json'
    );

    console.log('Looking for artifacts at:', artifactsPath);
    const dssJobsDeployArtifacts = await readFile(
      artifactsPath,
      'utf-8'
    );
    const addresses = JSON.parse(dssJobsDeployArtifacts);

    if (!addresses.sequencer) {
      throw new Error('Sequencer address not found in artifacts');
    }

    console.log('Found sequencer address:', addresses.sequencer);

    // Check if contract is deployed
    const isDeployed = await isContractDeployed(provider, addresses.sequencer);
    if (!isDeployed) {
      throw new Error(`No contract deployed at address ${addresses.sequencer}`);
    }
    console.log('✅ Sequencer contract is deployed');

    const sequencer = new ethers.Contract(
      addresses.sequencer,
      SEQUENCER_ABI,
      wallet
    );

    return {
      provider,
      wallet,
      sequencer
    };
  } catch (error) {
    if (error instanceof Error) {
      console.error(error);
      throw new Error(`Failed to load config: ${error.message}`);
    }
    throw error;
  }
}

startCron().catch((error) => {
  console.error('Failed to start cron job', {
    error: error.message
  });
  process.exit(1);
});