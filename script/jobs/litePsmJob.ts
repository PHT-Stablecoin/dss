import process from 'node:process';
import dotenv from 'dotenv'
import * as ethers from 'ethers'
import { Flapper__factory as Flap } from '../../typechain-types';
import { DssPsm__factory as Psm } from '../../typechain-types';

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
    const artifacts = await import("../output/1/dssDeploy.artifacts.json")

    const litePsm = 
    // Check rush, cut, and gush balances
    const rush = await litePsm.rush();
    const cut = await litePsm.cut();
    const gush = await litePsm.gush();

    if (rush.gte(RUSH_THRESHOLD)) {
    const tx = await litePsm.fill();
    console.log('Called fill():', tx.hash);
    await tx.wait();
    } else if (cut.gte(CUT_THRESHOLD)) {
    const tx = await litePsm.chug();
    console.log('Called chug():', tx.hash);
    await tx.wait();
    } else if (gush.gte(GUSH_THRESHOLD)) {
    const tx = await litePsm.trim();
    console.log('Called trim():', tx.hash);
    await tx.wait();
    } else {
    console.log('No action needed.');
    }

    // TODO: setup triggers and incentives and costs
    // setInterval(async () => {
    // }, 5 * 1000);
}

main().catch(e => {
    console.error(e);
    process.exit(1)
})