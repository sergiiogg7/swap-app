// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./interfaces/IV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Thrown when the router address is the zero address.
error ZeroAddress();

/// @notice Thrown when the input amount is zero.
error ZeroAmount();

/// @notice Thrown when the swap path has fewer than two tokens.
error InvalidPath();

/// @title SwapApp
/// @notice Thin Uniswap V2 wrapper that lets users swap ERC-20 tokens in a single transaction.
/// @dev Tokens are never held between calls: the contract pulls the input from the caller, approves the router
///      and the router sends the output directly to the caller in the same transaction.
contract SwapApp is ReentrancyGuard, Ownable2Step, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Address of the Uniswap V2 Router.
    address public immutable V2Router02Address;

    /// @notice Emitted on a successful token swap.
    /// @param tokenIn Address of the token sent by the user.
    /// @param tokenOut Address of the token received by the user.
    /// @param amountIn Exact input amount.
    /// @param amountOut Actual output amount received.
    event SwapTokens(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    /// @notice Deploys SwapApp and sets the router.
    /// @param v2Router_ Address of the Uniswap V2 Router.
    constructor(address v2Router_) Ownable(msg.sender) {
        if (v2Router_ == address(0)) revert ZeroAddress();
        V2Router02Address = v2Router_;
    }

    /// @notice Pauses swaps.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses swaps.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Swaps an exact amount of `path_[0]` for as many `path_[last]` tokens as possible.
    /// @dev Pulls `amountIn_` from the caller, approves the router and sends the output to the caller.
    ///      No tokens remain in the contract after the call.
    /// @param amountIn_ Exact amount of input tokens to send.
    /// @param amountOutMin_ Minimum acceptable output amount (slippage guard).
    /// @param path_ Ordered token route, for example [USDT, DAI].
    /// @param deadline_ Unix timestamp after which the transaction reverts.
    /// @return amountOut Actual amount of output tokens received by the caller.
    function swapTokens(uint256 amountIn_, uint256 amountOutMin_, address[] memory path_, uint256 deadline_)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amountOut)
    {
        if (amountIn_ == 0) revert ZeroAmount();
        if (path_.length < 2) revert InvalidPath();

        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        IERC20(path_[0]).forceApprove(V2Router02Address, amountIn_);

        uint256[] memory amounts = IV2Router02(V2Router02Address)
            .swapExactTokensForTokens(amountIn_, amountOutMin_, path_, msg.sender, deadline_);
        amountOut = amounts[amounts.length - 1];

        emit SwapTokens(path_[0], path_[path_.length - 1], amountIn_, amountOut);
    }
}
