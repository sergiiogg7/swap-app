// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SwapApp} from "../src/SwapApp.sol";

/// @notice Optional Arbitrum mainnet fork test. Skipped when `ARBITRUM_RPC_URL` is not set.
contract SwapAppForkTest is Test {
    address internal constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address internal constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address internal constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    SwapApp internal app;
    address internal user = makeAddr("user");

    function setUp() external {
        string memory rpc = vm.envOr("ARBITRUM_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc);
        app = new SwapApp(ROUTER);
    }

    function test_swapTokens_onArbitrumFork_swapsUsdtForDai() external {
        // Arrange
        uint256 amountIn = 5e6;
        deal(USDT, user, amountIn);
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;

        vm.startPrank(user);
        (bool ok,) = USDT.call(abi.encodeWithSignature("approve(address,uint256)", address(app), amountIn));
        assertTrue(ok);

        // Act
        uint256 amountOut = app.swapTokens(amountIn, 4e18, path, block.timestamp + 1 hours);
        vm.stopPrank();

        // Assert
        assertEq(IERC20(USDT).balanceOf(user), 0);
        assertEq(IERC20(DAI).balanceOf(user), amountOut);
        assertEq(IERC20(USDT).balanceOf(address(app)), 0);
    }
}
