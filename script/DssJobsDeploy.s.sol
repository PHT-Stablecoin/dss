// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity <=0.8.13;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

// Sequencer and Jobs imports
import { Sequencer } from "dss-cron/Sequencer.sol";
import { OracleJob } from "dss-cron/OracleJob.sol";
import { AutoLineJob } from "dss-cron/AutoLineJob.sol";
import { FlapJob } from "dss-cron/FlapJob.sol";
import { IJob } from "dss-cron/interfaces/IJob.sol";

interface IlkRegistryLike {
    function list() external view returns (bytes32[] memory);
    function pip(bytes32 ilk) external view returns (address);
}

interface SpotterLike {
    function ilks(bytes32) external view returns (address, uint256);
}

// Separate storage contract for artifacts
contract DssAddresses {
    address public authority;
    address public autoline;
    address public spotter;
    address public ilkRegistry;
    address public flap;
    address public vow;
    
    constructor(
        address _spotter,
        address _ilkRegistry
    ) {
        spotter = _spotter;
        ilkRegistry = _ilkRegistry;
    }
}

contract DssJobsDeployScript is Script, Test {
    using stdJson for string;

    bytes32 constant NET_MAIN = "NTWK-MAIN";
    uint256 constant NETWORK_WINDOW = 10;
    
    DssAddresses public addresses;
    Sequencer public sequencer;

    function loadArtifacts() internal {
        string memory root = vm.projectRoot();
        string memory path = string(
            abi.encodePacked(
                root, 
                "/script/output/", 
                vm.toString(block.chainid), 
                "/dssDeploy.artifacts.json"
            )
        );
        string memory json = vm.readFile(path);
        
        // Parse individual addresses from JSON
        address spotter = json.readAddress(".spotter");
        address ilkRegistry = json.readAddress(".ilkRegistry");
        
        addresses = new DssAddresses(
            spotter,
            ilkRegistry
        );
    }

    function deploySequencer() internal {
        sequencer = new Sequencer();
        sequencer.addNetwork(NET_MAIN, NETWORK_WINDOW);
        console.log("Sequencer deployed at: %s", address(sequencer));
    }

    function configureOracleJob() internal {
        require(address(sequencer) != address(0), "Sequencer not deployed");
        require(addresses.ilkRegistry() != address(0), "IlkRegistry not configured");
        require(addresses.spotter() != address(0), "Spotter not configured");
        
        OracleJob oracleJob = new OracleJob(
            address(sequencer),
            addresses.ilkRegistry(),
            addresses.spotter()
        );

        sequencer.addJob(address(oracleJob));
        console.log("OracleJob deployed at: %s", address(oracleJob));
    }

    function verifyJobs() internal {
        Sequencer.WorkableJob[] memory jobs = sequencer.getNextJobs(NET_MAIN);
        console.log("Verifying %d jobs", jobs.length);
        
        for (uint256 i = 0; i < jobs.length; i++) {
            console.log("Job %d: %s (workable: %s)", 
                i,
                address(jobs[i].job),
                jobs[i].canWork ? "true" : "false"
            );
        }
    }

    function run() public {
        vm.startBroadcast();

        // Load artifacts and deploy sequencer
        loadArtifacts();
        deploySequencer();
        
        // Configure jobs
        configureOracleJob();
        
        // Verify deployment
        verifyJobs();

        vm.stopBroadcast();
    }
}