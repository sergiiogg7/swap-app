// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SwapAppBase} from "./utils/SwapAppBase.sol";
import "../src/SwapApp.sol";

contract SwapAppFuzz is SwapAppBase {
    // Any positive amount settles 1:1 and leaves nothing in the contract.
    function testFuzz_swapTokens_anyAmount_settlesAndRetainsNothing(uint256 amountIn_) external {
        // Arrange
        amountIn_ = bound(amountIn_, 1, tokenA.balanceOf(user));
        uint256 balanceBefore = tokenA.balanceOf(user);

        // Act
        vm.prank(user);
        uint256 amountOut = app.swapTokens(amountIn_, 0, _path(address(tokenA), address(tokenB)), DEADLINE);

        // Assert
        assertEq(amountOut, amountIn_);
        assertEq(tokenA.balanceOf(user), balanceBefore - amountIn_);
        assertEq(tokenB.balanceOf(user), amountIn_);
        assertEq(tokenA.balanceOf(address(app)), 0);
        assertEq(tokenA.allowance(address(app), address(router)), 0);
    }

    // Any minimum above the output makes the router revert and leaves the user untouched.
    function testFuzz_swapTokens_withMinAboveOutput_revertsAndKeepsFunds(uint256 amountIn_, uint256 extra_) external {
        // Arrange
        amountIn_ = bound(amountIn_, 1, tokenA.balanceOf(user));
        extra_ = bound(extra_, 1, type(uint128).max);
        uint256 balanceBefore = tokenA.balanceOf(user);

        // Act
        vm.prank(user);
        vm.expectRevert("insufficient output");
        app.swapTokens(amountIn_, amountIn_ + extra_, _path(address(tokenA), address(tokenB)), DEADLINE);

        // Assert
        assertEq(tokenA.balanceOf(user), balanceBefore);
    }

    // Any path shorter than two tokens must revert with InvalidPath.
    function testFuzz_swapTokens_withShortPath_revertsWithInvalidPath(uint8 length_) external {
        // Arrange
        length_ = uint8(bound(length_, 0, 1));
        address[] memory path = new address[](length_);
        if (length_ == 1) path[0] = address(tokenA);

        // Act / Assert
        vm.prank(user);
        vm.expectRevert(InvalidPath.selector);
        app.swapTokens(1 ether, 0, path, DEADLINE);
    }

    // Longer paths settle and the output equals the amount in, whatever the hop count.
    function testFuzz_swapTokens_withLongPath_returnsLastAmount(uint8 hops_, uint256 amountIn_) external {
        // Arrange
        hops_ = uint8(bound(hops_, 2, 8));
        amountIn_ = bound(amountIn_, 1, 1_000_000 ether);
        address[] memory path = new address[](hops_);
        path[0] = address(tokenA);
        for (uint256 i = 1; i < hops_ - 1; i++) {
            path[i] = address(tokenC);
        }
        path[hops_ - 1] = address(tokenB);

        // Act
        vm.prank(user);
        uint256 amountOut = app.swapTokens(amountIn_, 0, path, DEADLINE);

        // Assert
        assertEq(amountOut, amountIn_);
    }
}
