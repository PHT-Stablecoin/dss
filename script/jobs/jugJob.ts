import process from 'node:process';
import dotenv from 'dotenv'
import * as ethers from 'ethers'
import { Jug__factory as Jug } from '../../typechain-types';

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

    const jug = Jug.connect(artifacts.jug, signer)
    const tx = await jug.drip.send(ethers.encodeBytes32String("ETH"))
    console.log(tx)
    const tx2 = await jug.drip.send(ethers.encodeBytes32String("USDT-A"))
    console.log(tx2)
    
    // TODO: setup triggers and incentives and costs
    // setInterval(async () => {
    // }, 5 * 1000);
}

main().catch(e => {
    console.error(e);
    process.exit(1)
})