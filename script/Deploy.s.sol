// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/SwapApp.sol";

/// @notice Deploys SwapApp using the router address read from the environment.
contract Deploy is Script {
    function run() external returns (SwapApp app) {
        address router = vm.envAddress("V2_ROUTER");

        vm.startBroadcast();
        app = new SwapApp(router);
        vm.stopBroadcast();

        console.log("SwapApp deployed at:", address(app));
    }
}
