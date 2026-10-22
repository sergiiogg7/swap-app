# SwapApp

A minimal Uniswap V2 swap wrapper for ERC-20 token swaps on Arbitrum.

## Overview

SwapApp is a thin smart contract that abstracts the complexity of interacting with Uniswap V2. Users approve tokens to the contract, call `swapTokens()`, and receive output tokens directly in their wallet. No tokens are held by the contract between swaps.

```
User --approve--> SwapApp --swapExactTokensForTokens--> Uniswap V2 Router
                  ^                                              |
                  +---------- Output Tokens <--------------------+
```

## Contract Reference

```solidity
function swapTokens(
    uint256 amountIn_,
    uint256 amountOutMin_,
    address[] memory path_,
    uint256 deadline_
) external returns (uint256 amountOut);

function pause() external;   // owner only
function unpause() external; // owner only
```

| Parameter | Description |
|---|---|
| `amountIn_` | Exact amount of input tokens to swap (cannot be zero) |
| `amountOutMin_` | Minimum amount of output tokens (slippage guard) |
| `path_` | Token route, at least two tokens, for example `[USDT, DAI]` |
| `deadline_` | Unix timestamp after which the call reverts |

The output goes to `msg.sender`. Custom errors: `ZeroAddress`, `ZeroAmount`, `InvalidPath`.

## Usage

1. Approve the SwapApp contract to spend your input tokens.
2. Call `swapTokens()` with the amount, minimum output, token path and deadline.

```solidity
address[] memory path = new address[](2);
path[0] = USDT; // token in
path[1] = DAI;  // token out

IERC20(USDT).approve(address(swapApp), amountIn);
swapApp.swapTokens(amountIn, amountOutMin, path, block.timestamp + 15 minutes);
```

## Security

| Measure | Location |
|---|---|
| Reentrancy guard | `SwapApp.swapTokens` (`nonReentrant`) |
| Pausable, owner can halt swaps | `SwapApp.pause`, `SwapApp.unpause` |
| Two-step ownership transfer | `Ownable2Step` |
| `SafeERC20` transfers and `forceApprove` (works with USDT-style tokens) | `SwapApp` |
| Router is immutable and validated at deployment | `SwapApp` constructor |
| Zero amount and paths shorter than two tokens rejected | `SwapApp.swapTokens` |
| Custom errors only | `SwapApp.sol` |
| Slither in CI | `slither.config.json` |

See [SECURITY.md](SECURITY.md) for assumptions and limits.

## Testing

Unit, fuzz and invariant suites use a mock router and mock tokens, so no fork is needed. An optional Arbitrum fork test runs only when `ARBITRUM_RPC_URL` is set.

```bash
forge test                                              # mock-based suites (fork test is skipped)
ARBITRUM_RPC_URL=<url> forge test --match-contract SwapAppForkTest -vvv
forge coverage --no-match-coverage "script|test"        # coverage of src/
forge snapshot --check                                  # gas regression check
```

CI runs `forge fmt --check`, `forge build --sizes`, `forge test` (profile `ci`, higher fuzz runs), a 95% line-coverage gate on `src/`, `forge snapshot --check` and Slither.

## Getting Started

```bash
git clone --recursive https://github.com/sergiiogg7/swap-app.git
cd swap-app
forge build
forge test
```

Deploy (router address read from the environment, see `.env.example`):

```bash
cp .env.example .env   # fill in values
source .env
forge script script/Deploy.s.sol --rpc-url $ARBITRUM_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## Tech Stack

- Solidity 0.8.24, Foundry
- OpenZeppelin v5: `SafeERC20`, `ReentrancyGuard`, `Ownable2Step`, `Pausable`
- Uniswap V2 router on Arbitrum

## Project Structure

```
swap-app/
├── src/
│   ├── SwapApp.sol
│   └── interfaces/IV2Router02.sol
├── test/                    # unit, fuzz, invariant, optional fork test, mocks and shared base
├── script/Deploy.s.sol
├── slither.config.json
├── SECURITY.md
└── foundry.toml
```

## License

MIT
