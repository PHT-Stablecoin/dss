pragma solidity <=0.8.13;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

// Sequencer and Jobs imports
import { Sequencer } from "dss-cron/Sequencer.sol";
import { OracleJob } from "dss-cron/OracleJob.sol";
import { IJob } from "dss-cron/interfaces/IJob.sol";

interface IlkRegistryLike {
    function list() external view returns (bytes32[] memory);
    function pip(bytes32 ilk) external view returns (address);
}

// Separate storage contract for artifacts
contract DssAddresses {
    address public spotter;
    address public ilkRegistry;
    
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
    OracleJob public oracleJob;

    function loadDssArtifacts() internal {
        string memory root = vm.projectRoot();   
        string memory dssArtifactsPath = string(
            abi.encodePacked(
                root, 
                "/script/output/", 
                vm.toString(block.chainid), 
                "/dssDeploy.artifacts.json"
            )
        );
        string memory json = vm.readFile(dssArtifactsPath);
        
        // Parse individual addresses from JSON
        address spotter = json.readAddress(".spotter");
        address ilkRegistry = json.readAddress(".ilkRegistry");
        
        addresses = new DssAddresses(
            spotter,
            ilkRegistry
        );
    }

    function addAddressesToArtifacts() internal {
        string memory root = vm.projectRoot();   
        string memory artifactsPath = string(
            abi.encodePacked(
                root, 
                "/script/output/", 
                vm.toString(block.chainid), 
                "/dssJobsDeploy.artifacts.json"
            )
        );
        string memory artifacts = "artifacts";
        
        artifacts.serialize("oracleJob", address(oracleJob));

        string memory json = artifacts.serialize("sequencer", address(sequencer));
        json.write(artifactsPath);
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
        
        oracleJob = new OracleJob(
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
        loadDssArtifacts();
        deploySequencer();
        
        // Configure jobs
        configureOracleJob();
        
        // Verify deployment
        verifyJobs();

        // Add deployed addresses to artifacts
        addAddressesToArtifacts();

        vm.stopBroadcast();
    }
}