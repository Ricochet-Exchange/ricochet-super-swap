# REXSuperSwap

Wrapper contract around Uniswap V3 to allow customers to swap super tokens. This contract uses the Uniswap liquidity for the underlying tokens, and returns the upgraded super tokens to the customer.

## Contract Deployment

- Constructor Argument
  - `ISwapRouter02 _swapRouter` - Contract address for the [Uniswap V3](https://docs.uniswap.org/protocol/reference/deployments) SwapRouter02 contract.
