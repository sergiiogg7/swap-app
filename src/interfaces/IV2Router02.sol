// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IV2Router02
/// @notice Minimal Uniswap V2 Router interface used by SwapApp.
interface IV2Router02 {
    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible.
    /// @param amountIn Exact amount of input tokens.
    /// @param amountOutMin Minimum amount of output tokens, reverts otherwise.
    /// @param path Ordered token route.
    /// @param to Recipient of the output tokens.
    /// @param deadline Unix timestamp after which the call reverts.
    /// @return amounts Amounts at each step of the route.
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
