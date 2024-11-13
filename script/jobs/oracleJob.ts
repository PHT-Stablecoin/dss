import { ethers } from 'ethers';
import { CronJob } from 'cron';

export class OracleJob {
  private provider: ethers.JsonRpcProvider;
  private wallet: ethers.Wallet;
  private sequencer: ethers.Contract;
  private oracleJob: ethers.Contract;
  private cronJob: CronJob;

  constructor(
    provider: ethers.JsonRpcProvider,
    privateKey: string,
    sequencerAddress: string,
    oracleJobAddress: string,
    schedule: string
  ) {
    // Setup wallet
    this.provider = provider;
    this.wallet = new ethers.Wallet(privateKey, this.provider);

    // Initialize contracts
    this.sequencer = new ethers.Contract(
      sequencerAddress,
      [
        'function getMaster() external view returns (bytes32)',
        'function isMaster(bytes32) external view returns (bool)'
      ],
      this.wallet
    );

    this.oracleJob = new ethers.Contract(
      oracleJobAddress,
      [
        'function work(bytes32 network, bytes calldata args) external',
        'function workable(bytes32 network) external view returns (bool, bytes memory)'
      ],
      this.wallet
    );

    this.cronJob = new CronJob(
      schedule,
      () => this.execute(),
      null,
      false, // Start automatically
      'UTC'
    );
  }

  async start() {
    console.log('==== Starting Oracle keeper... =====');
    console.log(`Schedule: ${this.cronJob.nextDate()}\n`);
    this.cronJob.start();
  }

  private async execute() {
    const now = new Date().toISOString();
    console.log(`\n==== Executing Oracle check at ${now} ====`);

    try {
      // Get current network from sequencer
      const network = await this.sequencer.getMaster();
      if (!network || network === ethers.ZeroHash) {
        console.log('No active network');
        return;
      }

      // Check if job is workable
      console.log('Checking workable status...');
      const response = await this.oracleJob.workable(network);
      console.log("Response", response);

      if (response[0]) {
        const [toPoke, spotterIlksToPoke] = ethers.AbiCoder.defaultAbiCoder().decode(
          ['bytes32[]', 'bytes32[]'],
          response[1]
        );

        console.log('Workable result:', {
          response,
          ilksToUpdate: toPoke.map((ilk: string) => ethers.decodeBytes32String(ilk)),
          spotterIlksToUpdate: spotterIlksToPoke.map((ilk: string) => ethers.decodeBytes32String(ilk))
        });

        // Execute job
        console.log('Executing Oracle job...');
        const tx = await this.oracleJob.work(network, response[1], {
          gasLimit: 500000
        });

        console.log('Oracle transaction sent:', tx.hash);
        const receipt = await tx.wait();
        console.log('Oracle job completed, gas used:', receipt.gasUsed.toString());
      } else {
        console.log('Oracle job not workable:', ethers.toUtf8String(response[1]));
      }
    } catch (error) {
      console.error('Error executing Oracle job:', error);
    }
  }

  async stop() {
    console.log('Stopping keeper...');
    this.cronJob.stop();
  }
}
