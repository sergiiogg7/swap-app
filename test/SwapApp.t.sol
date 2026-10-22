// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SwapAppBase} from "./utils/SwapAppBase.sol";
import {NoReturnToken, ReentrantToken} from "./mocks/Mocks.sol";
import "../src/SwapApp.sol";

contract SwapAppTest is SwapAppBase {
    // -------------------------------------------------------------------------
    // constructor
    // -------------------------------------------------------------------------

    function test_constructor_setsRouterAndOwner() external view {
        // Assert
        assertEq(app.V2Router02Address(), address(router));
        assertEq(app.owner(), owner);
    }

    function test_constructor_withZeroRouter_revertsWithZeroAddress() external {
        // Arrange / Act / Assert
        vm.expectRevert(ZeroAddress.selector);
        new SwapApp(address(0));
    }

    // -------------------------------------------------------------------------
    // pause and ownership
    // -------------------------------------------------------------------------

    function test_pause_andUnpause_toggleState() external {
        // Arrange / Act
        app.pause();

        // Assert
        assertTrue(app.paused());
        app.unpause();
        assertFalse(app.paused());
    }

    function test_pause_byNonOwner_reverts() external {
        // Arrange / Act / Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        app.pause();
    }

    function test_unpause_byNonOwner_reverts() external {
        // Arrange
        app.pause();

        // Act / Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        app.unpause();
    }

    function test_transferOwnership_isTwoStep() external {
        // Arrange / Act
        app.transferOwnership(user);

        // Assert
        assertEq(app.owner(), owner);
        assertEq(app.pendingOwner(), user);
        vm.prank(user);
        app.acceptOwnership();
        assertEq(app.owner(), user);
    }

    // -------------------------------------------------------------------------
    // swapTokens
    // -------------------------------------------------------------------------

    function test_swapTokens_withValidPath_movesTokensAndReturnsAmountOut() external {
        // Arrange
        uint256 amountIn = 1_000 ether;
        uint256 balanceBefore = tokenA.balanceOf(user);

        // Act
        vm.prank(user);
        uint256 amountOut = app.swapTokens(amountIn, 0, _path(address(tokenA), address(tokenB)), DEADLINE);

        // Assert
        assertEq(amountOut, amountIn);
        assertEq(tokenA.balanceOf(user), balanceBefore - amountIn);
        assertEq(tokenB.balanceOf(user), amountIn);
    }

    function test_swapTokens_leavesNoTokensOrAllowanceInContract() external {
        // Arrange / Act
        vm.prank(user);
        app.swapTokens(500 ether, 0, _path(address(tokenA), address(tokenB)), DEADLINE);

        // Assert
        assertEq(tokenA.balanceOf(address(app)), 0);
        assertEq(tokenB.balanceOf(address(app)), 0);
        assertEq(tokenA.allowance(address(app), address(router)), 0);
    }

    function test_swapTokens_withThreeHopPath_returnsLastAmountAndEmitsLastToken() external {
        // Arrange
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        vm.expectEmit(true, true, false, true);
        emit SwapApp.SwapTokens(address(tokenA), address(tokenC), 100 ether, 100 ether);

        // Act
        vm.prank(user);
        app.swapTokens(100 ether, 0, path, DEADLINE);

        // Assert
        assertEq(tokenC.balanceOf(user), 100 ether);
    }

    function test_swapTokens_emitsSwapTokens() external {
        // Arrange
        vm.expectEmit(true, true, false, true);
        emit SwapApp.SwapTokens(address(tokenA), address(tokenB), 500 ether, 500 ether);

        // Act
        vm.prank(user);
        app.swapTokens(500 ether, 0, _path(address(tokenA), address(tokenB)), DEADLINE);
    }

    function test_swapTokens_withZeroAmount_revertsWithZeroAmount() external {
        // Arrange / Act / Assert
        vm.prank(user);
        vm.expectRevert(ZeroAmount.selector);
        app.swapTokens(0, 0, _path(address(tokenA), address(tokenB)), DEADLINE);
    }

    function test_swapTokens_withSingleTokenPath_revertsWithInvalidPath() external {
        // Arrange
        address[] memory path = new address[](1);
        path[0] = address(tokenA);

        // Act / Assert
        vm.prank(user);
        vm.expectRevert(InvalidPath.selector);
        app.swapTokens(1 ether, 0, path, DEADLINE);
    }

    function test_swapTokens_withEmptyPath_revertsWithInvalidPath() external {
        // Arrange
        address[] memory path = new address[](0);

        // Act / Assert
        vm.prank(user);
        vm.expectRevert(InvalidPath.selector);
        app.swapTokens(1 ether, 0, path, DEADLINE);
    }

    function test_swapTokens_whenPaused_reverts() external {
        // Arrange
        app.pause();

        // Act / Assert
        vm.prank(user);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        app.swapTokens(1 ether, 0, _path(address(tokenA), address(tokenB)), DEADLINE);
    }

    function test_swapTokens_afterUnpause_works() external {
        // Arrange
        app.pause();
        app.unpause();

        // Act
        vm.prank(user);
        app.swapTokens(1 ether, 0, _path(address(tokenA), address(tokenB)), DEADLINE);

        // Assert
        assertEq(tokenB.balanceOf(user), 1 ether);
    }

    function test_swapTokens_withMinOutputTooHigh_reverts() external {
        // Arrange / Act / Assert
        vm.prank(user);
        vm.expectRevert("insufficient output");
        app.swapTokens(1 ether, 2 ether, _path(address(tokenA), address(tokenB)), DEADLINE);
    }

    function test_swapTokens_afterDeadline_reverts() external {
        // Arrange
        vm.warp(1000);

        // Act / Assert
        vm.prank(user);
        vm.expectRevert("expired");
        app.swapTokens(1 ether, 0, _path(address(tokenA), address(tokenB)), 999);
    }

    function test_swapTokens_withoutAllowance_reverts() external {
        // Arrange
        address stranger = makeAddr("stranger");
        tokenA.mint(stranger, 1 ether);

        // Act / Assert
        vm.prank(stranger);
        vm.expectRevert();
        app.swapTokens(1 ether, 0, _path(address(tokenA), address(tokenB)), DEADLINE);
    }

    function test_swapTokens_withNoReturnToken_succeeds() external {
        // Arrange
        NoReturnToken usdtLike = new NoReturnToken();
        usdtLike.mint(user, 100 ether);
        vm.startPrank(user);
        // Raw call: the token returns no data, so the typed IERC20 interface cannot be used here.
        (bool ok,) = address(usdtLike).call(abi.encodeCall(NoReturnToken.approve, (address(app), 100 ether)));
        assertTrue(ok);

        // Act
        app.swapTokens(100 ether, 0, _path(address(usdtLike), address(tokenB)), DEADLINE);
        vm.stopPrank();

        // Assert
        assertEq(tokenB.balanceOf(user), 100 ether);
        assertEq(usdtLike.balanceOf(address(app)), 0);
        assertEq(usdtLike.allowance(address(app), address(router)), 0);
    }

    function test_swapTokens_withReentrantToken_revertsWithReentrancyGuard() external {
        // Arrange
        ReentrantToken evil = new ReentrantToken();
        evil.setApp(app);
        evil.mint(user, 10 ether);
        vm.prank(user);
        evil.approve(address(app), type(uint256).max);

        // Act / Assert
        vm.prank(user);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        app.swapTokens(1 ether, 0, _path(address(evil), address(tokenB)), DEADLINE);
    }
}
