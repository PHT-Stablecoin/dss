import process from 'node:process';
import dotenv from 'dotenv'
import * as ethers from 'ethers'
import { Spotter__factory as Spot } from '../../typechain-types';
import { Vow__factory as Vow } from '../../typechain-types';
import { Jug__factory as Jug } from '../../typechain-types';
import { Vat___factory as Vat } from '../../typechain-types';
import { OracleJob } from './oracleJob';

interface DssEnv {
    MAINNET_RPC_URL?: string;
    LOCAL_RPC_URL?: string;
    PRIVATE_KEY?: string;
}

const main = async () => {
    dotenv.config({ path: "../../.env.development" })
    const dssEnv = process.env as DssEnv;
    const provider = new ethers.JsonRpcProvider(dssEnv.LOCAL_RPC_URL!)
    const signer = await provider.getSigner()
    const network = await provider.getNetwork()

    const artifacts = await import(`../output/${network.chainId}/dssDeploy.artifacts.json`)

    const spot = Spot.connect(artifacts.spotter, signer)
    const vow = Vow.connect(artifacts.vow, signer)
    const vat = Vat.connect(artifacts.vat, signer)
    const jug = Jug.connect(artifacts.jug, signer)

    // Oracle Job
    // const oracleJob = async () => {
    //     const tx = await spot.poke.send(ethers.encodeBytes32String("ETH"))
    //     console.log(tx)
    //     const tx2 = await spot.poke.send(ethers.encodeBytes32String("USDT-A"))
    //     console.log(tx2)
    // }
    const oracleJobSchedule = process.env.ORACLE_JOB_SCHEDULE || '*/30 * * * *'; // Default is very 30 minutes
    const oracleJob = new OracleJob(
        provider,
        process.env.KEEPER_PRIVATE_KEY!,
        artifacts.sequencer,
        artifacts.oracleJob,
        oracleJobSchedule
    );
    await oracleJob.start();

    const jugJob = async () => {
        const tx = await jug.drip.send(ethers.encodeBytes32String("ETH"))
        console.log(tx)
        const tx2 = await jug.drip.send(ethers.encodeBytes32String("USDT-A"))
        console.log(tx2)
    }

    const flapJob = async () => {
        // Check surplus
        const sin = await vow.Sin();
        const ash = await vow.Ash();
        const surplus = await vat.sin(artifacts.vow);

        const unbackedTotal = surplus;
        const unbackedVow = sin + ash
        const toHeal = unbackedTotal > unbackedVow ? unbackedTotal - unbackedVow : 0n;
        if (toHeal > 0) {
            const txHeal = await vow.heal.send(toHeal);
            console.log('vow.heal()', txHeal);
        }
        const txFlap = await vow.flap.send()
        console.log('vow.flap()', txFlap)

    }

    // TODO: setup triggers and incentives and costs
    setInterval(async () => {

        // console.log("========== ORACLE JOB ==========");
        // await oracleJob()
        console.log("========== JUG JOB    ==========");
        await jugJob();
        console.log("========== FLAP JOB   ==========");
        await flapJob();

    }, 5 * 1000);
}

main().catch(e => {
    console.error(e);
    process.exit(1)
})