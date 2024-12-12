import process from 'node:process';
import dotenv from 'dotenv'
import * as ethers from 'ethers'
import { Flapper__factory as Flap } from '../../typechain-types';
import { Vow__factory as Vow } from '../../typechain-types';
import { Vat___factory as Vat } from '../../typechain-types';

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

    const vow = Vow.connect(artifacts.vow, signer)
    const vat = Vat.connect(artifacts.vat, signer)

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

    // TODO: setup triggers and incentives and costs
    // setInterval(async () => {
    // }, 5 * 1000);
}

main().catch(e => {
    console.error(e);
    process.exit(1)
})