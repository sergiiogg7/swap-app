// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {SwapAppBase} from "./utils/SwapAppBase.sol";
import {SwapApp} from "../src/SwapApp.sol";
import {MockERC20} from "./mocks/Mocks.sol";

/// @notice Drives random swaps from several actors.
contract SwapAppHandler is Test {
    SwapApp public app;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    address[] public actors;

    uint256 public ghostSwapped;

    constructor(SwapApp app_, MockERC20 tokenA_, MockERC20 tokenB_) {
        app = app_;
        tokenA = tokenA_;
        tokenB = tokenB_;
        for (uint256 i = 0; i < 3; i++) {
            actors.push(makeAddr(string.concat("actor", vm.toString(i))));
        }
    }

    function swap(uint256 actorSeed_, uint256 amount_) external {
        address actor = actors[actorSeed_ % actors.length];
        amount_ = bound(amount_, 1, 1_000 ether);

        tokenA.mint(actor, amount_);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.startPrank(actor);
        tokenA.approve(address(app), amount_);
        app.swapTokens(amount_, 0, path, type(uint256).max);
        vm.stopPrank();

        ghostSwapped += amount_;
    }
}

contract SwapAppInvariant is SwapAppBase {
    SwapAppHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new SwapAppHandler(app, tokenA, tokenB);
        targetContract(address(handler));
    }

    // The app never holds input or output tokens between calls.
    function invariant_appHoldsNoTokens() external view {
        assertEq(tokenA.balanceOf(address(app)), 0);
        assertEq(tokenB.balanceOf(address(app)), 0);
    }

    // The app never leaves an allowance on the router.
    function invariant_noResidualAllowance() external view {
        assertEq(tokenA.allowance(address(app), address(router)), 0);
    }

    // Everything swapped by actors arrives as output tokens, nothing is lost or created.
    function invariant_outputEqualsAmountSwapped() external view {
        uint256 received;
        for (uint256 i = 0; i < 3; i++) {
            received += tokenB.balanceOf(handler.actors(i));
        }
        assertEq(received, handler.ghostSwapped());
    }
}
