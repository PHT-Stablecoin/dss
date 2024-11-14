pragma solidity <=0.8.13;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
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
import { IJob } from "dss-cron/interfaces/IJob.sol";


interface IlkRegistryLike {
    function list() external view returns (bytes32[] memory);
    function pip(bytes32 ilk) external view returns (address);
}

interface IChainLogLike {
    function getAddress(bytes32 _key) external view returns (address addr);
}

struct DssDeployArtifacts {
  address authority;
  address autoline;
  address cat;
  address clog;
  address cure;
  address dai;
  address daiJoin;
  address dog;
  address dssDeploy;
  address end;
  address esm;
  address feedCOL3;
  address flap;
  address flop;
  address ilkRegistry;
  address jug;
  address pipCOL3;
  address pipETH;
  address pipUSDT;
  address pipXINF;
  address pot;
  address psm;
  address spotter;
  address vat;
  address vow;
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
    
    bytes32[] private toPoke;
    bytes32[] private spotterIlksToPoke;

    DssDeployArtifacts artifacts;
    Sequencer sequencer;

    function chainId() internal view returns (uint256 _chainId) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _chainId := chainid()
        }
    }
    function run() public {
        vm.startBroadcast();
        string memory root = vm.projectRoot();

        string memory path = string(
            abi.encodePacked(root, "/script/output/", vm.toString(chainId()), "/dssDeploy.artifacts.json")
        );
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        artifacts = abi.decode(data, (DssDeployArtifacts));

        sequencer = new Sequencer();
        sequencer.addNetwork(NET_MAIN, 10);

        bytes32[] memory v = IlkRegistryLike(artifacts.ilkRegistry).list();

        OracleJob oracleJob = new OracleJob(address(sequencer), artifacts.ilkRegistry, artifacts.spotter);
        
        sequencer.addJob(address(oracleJob));
        
        // Sequencer.WorkableJob[] memory jobs = sequencer.getNextJobs(NET_MAIN);
        // for (uint256 i = 0; i < jobs.length; i++) {
        //     if (jobs[i].canWork) {
        //         IJob(jobs[i].job).work(NET_MAIN, jobs[i].args);
        //     }
        // }

        vm.stopBroadcast();
    }
}
