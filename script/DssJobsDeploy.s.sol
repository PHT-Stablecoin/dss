pragma solidity <=0.8.13;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

// Sequencer
import { Sequencer } from "dss-cron/Sequencer.sol";

// Jobs
import { AutoLineJob } from "dss-cron/AutoLineJob.sol";
import { ClipperMomJob } from "dss-cron/ClipperMomJob.sol";
import { D3MJob } from "dss-cron/D3MJob.sol";
import { FlapJob } from "dss-cron/FlapJob.sol";
import { LerpJob } from "dss-cron/LerpJob.sol";
import { LiquidatorJob } from "dss-cron/LiquidatorJob.sol";
import { LitePsmJob } from "dss-cron/LitePsmJob.sol";
import { NetworkPaymentAdapter } from "dss-cron/NetworkPaymentAdapter.sol";
import { OracleJob } from "dss-cron/OracleJob.sol";
import { Sequencer } from "dss-cron/Sequencer.sol";
import { VestedRewardsDistributionJob } from "dss-cron/VestedRewardsDistributionJob.sol";

interface IChainLogLike {
    function getAddress(bytes32 _key) external view returns (address addr);
}

struct DssDeployArtifacts {
    address clog;
    address vat;
    address jug;
    address vow;
    address cat;
    address dog;
    address flap;
    address flop;
    address dai;
    address daiJoin;
    address spotter;
    address pot;
    address cure;
    address end;
    address esm;
    address psm;
    address autoline;
    address ilkRegistry;
    address dssDeploy;
}

contract DssJobsDeployScript is Script, Test {
    using stdJson for string;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    // Governance Parameters
    uint256 constant INITIAL_XINF_SUPPLY = 1000000 * WAD;
    uint256 constant INITIAL_USDT_SUPPLY = 10000000 * (10 ** 6); // USDT has 6 decimals

    // Network
    bytes32 constant NET_MAIN = "NTWK-MAIN";

    DssDeployArtifacts artifacts;
    Sequencer sequencer;

    function run() public {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/script/output/1/dssDeploy.artifacts.json"));
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        artifacts = abi.decode(data, (DssDeployArtifacts));

        sequencer = new Sequencer();
        sequencer.addNetwork(NET_MAIN, 10);

        // oracleJob = new OracleJob(address(sequencer), artifacts.ilkRegistry)
    }

}