# Security

## Status

This repository has not been externally audited. Do not use it with real funds without an independent review.

## Assumptions and known limits

- The router is the genuine Uniswap V2 router. It is set at deployment and cannot be changed.
- `swapTokens` accepts any path, so callers choose the tokens they trust. A malicious token in the path can only affect the caller's own swap and cannot reenter the contract (`nonReentrant`).
- Fee-on-transfer tokens are not supported: the contract approves and swaps the nominal `amountIn_`.
- Slippage and expiry protection come from `amountOutMin_` and `deadline_`, which the caller must set sensibly. The contract does not enforce a minimum.
- Tokens sent directly to the contract are not recoverable. The contract has no rescue function by design.

## Invariants

- The contract holds no input or output tokens between calls.
- The contract leaves no allowance on the router after a call.

## Reporting a vulnerability

Open a private security advisory on the GitHub repository. Do not open a public issue.
