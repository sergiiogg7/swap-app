# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
forge build
forge test -vvv
forge test --match-test <name> -vvvv
forge coverage --no-match-coverage "script|test"   # coverage of src/ (CI gate: 95% lines)
forge snapshot --check                              # gas regression check
forge fmt --check                                   # CI enforces formatting
ARBITRUM_RPC_URL=<url> forge test --match-contract SwapAppForkTest -vvv   # optional fork test
```

## Architecture

One contract, `src/SwapApp.sol` (`ReentrancyGuard`, `Ownable2Step`, `Pausable`): a thin Uniswap V2 wrapper with a single function, `swapTokens(amountIn, amountOutMin, path, deadline)`. It pulls the input from the caller, approves the router with `forceApprove`, and the router sends the output to `msg.sender`. The contract holds no tokens between calls.

- The router is an `immutable` set in the constructor (`V2Router02Address`, zero address rejected).
- Custom errors (`ZeroAddress`, `ZeroAmount`, `InvalidPath`) are file-level declarations in `SwapApp.sol`.
- `src/interfaces/IV2Router02.sol` is the minimal local router interface.

## Tests

`test/utils/SwapAppBase.sol` holds the shared setup. `SwapApp.t.sol` (unit), `SwapAppFuzz.t.sol` and `SwapAppInvariant.t.sol` (handler with ghost variable) extend it. Mocks (`MockERC20`, `MockRouter`, `NoReturnToken`, `ReentrantToken`) live in `test/mocks/Mocks.sol`. `SwapAppFork.t.sol` is an optional Arbitrum fork test that skips when `ARBITRUM_RPC_URL` is unset.

Tests are named `test_<function>_<scenario>_<result>` with `// Arrange`, `// Act`, `// Assert` blocks.

## CI

`.github/workflows/test.yml` runs `forge fmt --check`, `forge build --sizes`, `forge test` (profile `ci`), a 95% line-coverage gate on `src/`, `forge snapshot --check` and Slither. Update `.gas-snapshot` with `forge snapshot` after intentional gas changes.
