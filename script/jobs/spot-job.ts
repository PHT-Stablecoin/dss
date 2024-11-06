import process from 'node:process';
import dotenv from 'dotenv'
import * as ethers from 'ethers'

interface DssEnv {
    MAINNET_RPC_URL?: string;
    LOCAL_RPC_URL?: string;
    PRIVATE_KEY?: string;
}
const SPOT_ABI = [
    "function poke(bytes32 ilk)"
]

const main = async () => {
    dotenv.config({ path: "../../.env.development" })
    const dssEnv = process.env as DssEnv;
    const provider = new ethers.JsonRpcProvider(dssEnv.LOCAL_RPC_URL!)
    const signer = await provider.getSigner()
    const artifacts = await import("../output/1/dssDeploy.artifacts.json")

    const spot = new ethers.Contract(artifacts.spot, SPOT_ABI, signer);
    
    // TODO: setup triggers and incentives and costs
    setInterval(async () => {
        const tx = await spot.poke("ETH")
        const tx2 = await spot.poke("USDT-A")
    }, 5 * 1000);
}

main()
    .catch(e => {
        console.error(e);
        process.exit(1);
    })
    .then(process.exit(0))