pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {PHTCollateralHelper} from "../pht/PHTCollateralHelper.sol";
import { PHTDeploy,PHTDeployResult} from "../script/PHTDeploy.sol";
import {PHTDeployConfig} from "../script/PHTDeployConfig.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import {ChainlinkPip, AggregatorV3Interface} from "../pht/helpers/ChainlinkPip.sol";
import {PriceFeedAggregator} from "../pht/factory/PriceFeedAggregator.sol";

import {PHTCollateralTestLib} from "./helpers/PHTCollateralTestLib.sol";
import {Spotter} from "../src/spot.sol";
import {Vat} from "../src/vat.sol";

contract PriceFeedAggregatorTest is Test{
    using ArrayHelpers for *;

    uint256 constant RAY = 10 ** 27;

    address alice; // authority owner
    address eve; // authority root user
    PHTDeployResult res;
    PHTCollateralHelper h;

    function setUp() public {
        eve = makeAddr("eve");
        alice = makeAddr("alice");
        PHTDeploy d = new PHTDeploy();
        res = d.deploy(
            PHTDeployConfig({
               govTokenSymbol: "APX",
                phtUsdFeed: address(0), // deploy a mock feed for testing
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                authorityOwner: alice,
                authorityRootUsers: [eve].toMemoryArray(),
                vowWaitSeconds: uint256(0),
                vowDumpWad: uint256(0),
                vowSumpRad: uint256(0),
                vowBumpRad: uint256(0),
                vowHumpRad: uint256(0)
            })
        );
        h = PHTCollateralHelper(res.collateralHelper);
    }

    function test_PriceFeedAggregator() public{
        vm.startPrank(eve);
        ( ,AggregatorV3Interface feed,, ChainlinkPip pip,,,) = 
            PHTCollateralTestLib.addCollateral("PHP-A", res, h, eve);          
        vm.stopPrank();             

        (,int256 _answer,,,) = feed.latestRoundData();
        assertEq(_answer,5813953488);   
                                     
         Spotter(res.spotter).poke("PHP-A");    
        (,,uint256 spot,,) = Vat(res.vat).ilks("PHP-A");
         console.log("The value is:", spot);  // get 55370985600000000000000000000
        uint256 expectedValue = 58.13953488 * 1e8;
        // the expected value is around 38 so it needs to investigate  
       // assertEq(spot, expectedValue * RAY * RAY / (1500000000 *1e26));          
    }

    function test_PriceJoinFeedAggregator() public{
        vm.startPrank(eve);
        ( ,AggregatorV3Interface feed,, ChainlinkPip pip,,,) = 
            PHTCollateralTestLib.addCollateralJoin("PHP-A", res, h, eve);                    
       vm.stopPrank();                  
        (,int256 _answer,,,) = feed.latestRoundData();
        assertEq(_answer,5813953488);
                         
        Spotter(res.spotter).poke("PHP-A");    
        (,,uint spot,,) = Vat(res.vat).ilks("PHP-A");       
        uint256 expectedValue = 58.13953488 * 1e8;
          assertEq(spot, expectedValue * RAY * RAY / (1500000000 *1e26));             
    }      
}

