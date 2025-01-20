pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

// anvil --fork-url YOUR_RPC_URL \
//    --fork-block-number 19000000 \
//    --block-time 1

// Run the test/helper scripts after starting Anvil
contract ForkConfig is Test {
    uint256 mainnetFork;
    uint256 forkBlock = 19000000;

    // Addresses
    // address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public virtual {
        mainnetFork = vm.createFork(vm.envString("ETH_RPC_URL"), forkBlock);
        vm.selectFork(mainnetFork);
    }

    // Helper to deal specific tokens to test addresses
    function dealTokens(address token, address to, uint256 amount) internal {
        deal(token, to, amount, true);
    }
}
