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

interface VaultLike {
    function ilk() external view returns (bytes32);
    function roles() external view returns (address);
    function buffer() external view returns (address);
    function vat() external view returns (address);
    function usds() external view returns (address);
    function file(bytes32, address) external;
}

interface VatLike {
    function ilks(bytes32 ilk) external view returns (
        uint256 Art,
        uint256 rate,
        uint256 spot,
        uint256 line,
        uint256 dust
    );
}

interface PokeLike {
    function poke() external;
}

interface SpotterLike {
    function vat() external view returns (address);
    function poke(bytes32 ilk) external;
}

// Note: Alphabetical order
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

    function run() public {
        vm.startBroadcast();
        string memory root = vm.projectRoot();

        string memory path = string(
            abi.encodePacked(root, "/script/output/", vm.toString(block.chainid), "/dssDeploy.artifacts.json")
        );
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        artifacts = abi.decode(data, (DssDeployArtifacts));

        sequencer = new Sequencer();
        sequencer.addNetwork(NET_MAIN, 10);

        bytes32[] memory v = IlkRegistryLike(artifacts.ilkRegistry).list();
        console.log("v[0]", vm.toString(v[0]));
        OracleJob oracleJob = new OracleJob(address(sequencer), artifacts.ilkRegistry, artifacts.spotter);
        sequencer.addJob(address(oracleJob));
        
        // console.log("++++++++HERE");
        // (bool isWorkable,) = oracleJob.workable(NET_MAIN);
        // assertTrue(isWorkable);

        Sequencer.WorkableJob[] memory jobs = sequencer.getNextJobs(NET_MAIN);
        console.log("===========HERE");

        console.log("jobs.length", jobs.length);
        console.logBytes(jobs[0].args);
        (, bytes memory localPayload) = this.workable(NET_MAIN);
        bytes memory badPayload = jobs[0].args;

        console.logBytes(localPayload);
        console.logBytes(badPayload);


        (bytes32[] memory _toPoke, bytes32[] memory _spotterIlksToPoke) = abi.decode(jobs[0].args, (bytes32[], bytes32[]));
        console.log("jobs.length", jobs.length);

        for (uint256 i = 0; i < jobs.length; i++) {

            console.logBytes32(_toPoke[0]);
            console.logBytes32( _spotterIlksToPoke[0]);
            console.log("CanWork", jobs[i].canWork);

            IJob(jobs[i].job).work(NET_MAIN, jobs[i].args);
            // work(NET_MAIN, jobs[i].args);
        }

        vm.stopBroadcast();
    }

    function work(bytes32, bytes memory args) internal {
        (bytes32[] memory _toPoke, bytes32[] memory _spotterIlksToPoke) = abi.decode(args, (bytes32[], bytes32[]));
        uint256 numSuccessful = 0;
        for (uint256 i = 0; i < _toPoke.length; i++) {
            bytes32 ilk = _toPoke[i];
            (uint256 Art,,, uint256 line,) = VatLike(artifacts.vat).ilks(ilk);
            if (Art == 0 && line == 0) continue;
            PokeLike pip = PokeLike(IlkRegistryLike(artifacts.ilkRegistry).pip(ilk));
            console.log("pip", address(pip));
            try pip.poke() {
                console.log("poked");
                numSuccessful++;
            } catch {
            }
        }
        for (uint256 i = 0; i < _spotterIlksToPoke.length; i++) {
            bytes32 ilk = _spotterIlksToPoke[i];
            (uint256 Art,,  uint256 beforeSpot, uint256 line,) = VatLike(artifacts.vat).ilks(ilk);
            if (Art == 0 && line == 0) continue;
            SpotterLike(artifacts.spotter).poke(ilk);
            (,,  uint256 afterSpot,,) = VatLike(artifacts.vat).ilks(ilk);
            if (beforeSpot != afterSpot) {
                numSuccessful++;
            }
        }
    }

    function workable(bytes32 network) external returns (bool, bytes memory) {
        // if (!sequencer.isMaster(network)) return (false, bytes("Network is not master"));

        delete toPoke;
        delete spotterIlksToPoke;
        
        VatLike vat = VatLike(artifacts.vat);
        IlkRegistryLike ilkRegistry = IlkRegistryLike(artifacts.ilkRegistry);
        SpotterLike spotter = SpotterLike(artifacts.spotter);

        bytes32[] memory ilks = ilkRegistry.list();
        for (uint256 i = 0; i < ilks.length; i++) {
            bytes32 ilk = ilks[i];
            PokeLike pip = PokeLike(ilkRegistry.pip(ilk));

            if (address(pip) == address(0)) continue;
            (uint256 Art,,  uint256 beforeSpot, uint256 line,) = vat.ilks(ilk);
            if (Art == 0 && line == 0) continue; // Skip if no debt / line

            // Just try to poke the oracle and add to the list if it works
            // This won't add an OSM twice
            try pip.poke() {
                toPoke.push(ilk);
            } catch {
            }

            // See if the spot price changes
            spotter.poke(ilk);
            (,,  uint256 afterSpot,,) = vat.ilks(ilk);
            if (beforeSpot != afterSpot) {
                spotterIlksToPoke.push(ilk);
            }
        }

        if (toPoke.length > 0 || spotterIlksToPoke.length > 0) {
            return (true, abi.encode(toPoke, spotterIlksToPoke));
        } else {
            return (false, bytes("No ilks ready"));
        }
    }
}
