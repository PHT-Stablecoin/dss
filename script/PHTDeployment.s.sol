pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {PHTDeploy, PHTDeployResult} from "../pht/PHTDeploy.sol";
import {PHTDeployConfig, PHTDeployCollateralConfig} from "../pht/PHTDeployConfig.sol";
import {DSRoles} from "../pht/lib/Roles.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";

contract PHTDeploymentScript is Script, PHTDeploy, Test {
    using ArrayHelpers for *;
    using stdJson for string;

    function run() public {
        vm.startBroadcast();

        console.log("[PHTDeploymentScript] starting...");
        console.log("[PHTDeploymentScript] msg.sender \t", msg.sender);
        console.log("[PHTDeploymentScript] address(this) \t", address(this));
        console.log("[PHTDeploymentScript] chainId \t", chainId());
        console.log("[PHTDeploymentScript] block.timestamp ", block.timestamp);
        console.log("[PHTDeploymentScript] block.number \t", block.number);
        console.log(
            '[PHTDeploymentScript] \x1b[0m\x1b[33mNOTE: can ignore the below warning \n\t\t\t"Script [...] which does not contains any code." \x1b[1m\n\t\t\tif the address matches:',
            address(this),
            "\x1b[0m"
        );

        PHTDeployCollateralConfig[] memory collateralConfigs = new PHTDeployCollateralConfig[](0);
        PHTDeployResult memory r = this.deploy(
            PHTDeployConfig({
                govTokenSymbol: "APC",
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                authorityOwner: msg.sender,
                authorityRootUsers: [msg.sender].toMemoryArray(),
                collateralConfigs: collateralConfigs
            })
        );
        vm.stopBroadcast();

        writeArtifacts(r);

        assertTrue(DSRoles(r.authority).isUserRoot(msg.sender), "msg.sender is root");
    }

    function writeArtifacts(PHTDeployResult memory r) public {
        string memory root = vm.projectRoot();
        string memory path = string(
            abi.encodePacked(root, "/script/output/", vm.toString(chainId()), "/dssDeploy.artifacts.json")
        );

        console.log("[PHTDeploymentScript] writing artifacts to", path);

        string memory artifacts = "artifacts";
        // --- Auth ---
        artifacts.serialize("authority", r.authority);
        artifacts.serialize("dssProxyActions", r.dssProxyActions);
        artifacts.serialize("proxyActions", r.proxyActions);
        artifacts.serialize("dssCdpManager", r.dssCdpManager);
        artifacts.serialize("dsrManager", r.dsrManager);
        artifacts.serialize("gov", r.gov);
        artifacts.serialize("ilkRegistry", r.ilkRegistry);
        artifacts.serialize("pause", r.pause);
        // --- MCD ---
        artifacts.serialize("vat", r.vat);
        artifacts.serialize("jug", r.jug);
        artifacts.serialize("vow", r.vow);
        artifacts.serialize("cat", r.cat);
        artifacts.serialize("dog", r.dog);
        artifacts.serialize("flap", r.flap);
        artifacts.serialize("flop", r.flop);
        artifacts.serialize("dai", r.dai);
        artifacts.serialize("daiJoin", r.daiJoin);
        artifacts.serialize("spotter", r.spotter);
        artifacts.serialize("pot", r.pot);
        artifacts.serialize("cure", r.cure);
        artifacts.serialize("end", r.end);
        artifacts.serialize("esm", r.esm);
        // --- ChainLog ---
        artifacts.serialize("clog", r.clog);

        // --- Factories ---
        artifacts.serialize("feedFactory", r.feedFactory);
        artifacts.serialize("joinFeedFactory", r.joinFeedFactory);

        // --- Helpers ----
        string memory json = artifacts.serialize("collateralHelper", r.collateralHelper);

        json.write(path);
    }
}
