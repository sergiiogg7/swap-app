// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {SwapApp} from "../../src/SwapApp.sol";
import {MockERC20, MockRouter} from "../mocks/Mocks.sol";

/// @dev Shared deployment and helpers for the SwapApp test suites.
abstract contract SwapAppBase is Test {
    SwapApp internal app;
    MockRouter internal router;
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    MockERC20 internal tokenC;

    address internal owner = address(this);
    address internal user = makeAddr("user");

    uint256 internal constant DEADLINE = type(uint256).max;

    function setUp() public virtual {
        router = new MockRouter();
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        tokenC = new MockERC20("Token C", "TKC");
        app = new SwapApp(address(router));

        tokenA.mint(user, 1_000_000 ether);
        vm.prank(user);
        tokenA.approve(address(app), type(uint256).max);
    }

    function _path(address from_, address to_) internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = from_;
        path[1] = to_;
    }
}
