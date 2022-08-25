//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IWMATIC.sol";

contract RexSuperSwap {
    ISwapRouter02 public immutable swapRouter;
    address public nativeToken;
    IWMATIC public nativeWrappedToken;

    event SuperSwapComplete(uint256 amountOut);

    constructor(ISwapRouter02 _swapRouter, address _nativeToken, IWMATIC _nativeWrappedToken) {
        swapRouter = _swapRouter;
        nativeToken = _nativeToken;
        nativeWrappedToken = _nativeWrappedToken;
    }

    receive() external payable {}

    // Having unlimited approvals rather then dealing with decimal converisons.
    // Not a problem as contract is not storing any tokens.
    function approve(IERC20 _token, address _spender) internal {
        if (_token.allowance(_spender, msg.sender) == 0) {
            TransferHelper.safeApprove(address(_token), address(_spender), ((2 ** 256) - 1));
        }
    }

    /**
    * @dev Swaps `amountIn` of `_from` SuperToken for at least `amountOutMin`
    * of `_to` SuperToken through `path` with `poolFees` fees for each pair.
    *
    * Returns the amount of `_to` SuperToken received.
    */
    function swap(
        ISuperToken _from,
        ISuperToken _to,
        uint256 amountIn,
        uint256 amountOutMin, // Use underlaying decimals
        address[] memory path,
        uint24[] memory poolFees, // Example: 0.3% * 10000 = 3000
        bool _hasUnderlyingFrom,
        bool _hasUnderlyingTo
    ) external payable returns (uint256 amountOut) {
        require(amountIn > 0, "Amount cannot be 0");
        require(path.length > 1, "Incorrect path");
        require(
            poolFees.length == path.length - 1,
            "Incorrect poolFees length"
        );

        // Step 1: Get underlying tokens and verify path
        address fromBase = address(_from);
        if (_hasUnderlyingFrom) {
            fromBase = _from.getUnderlyingToken();
        }

        bool isSourceNative = false;
        if (fromBase == nativeToken) {
            require(msg.value == amountIn, "Amount must match msg.value");
            nativeWrappedToken.deposit{ value: amountIn };
            fromBase = address(nativeWrappedToken);
            isSourceNative = true;
        }

        address toBase = address(_to);
        if (_hasUnderlyingTo) {
            toBase = _to.getUnderlyingToken();
        }

        require(path[0] == fromBase, "Invalid 'from' base token");
        require(path[path.length - 1] == toBase, "Invalid 'to' base token");

        // Step 2: Transfer SuperTokens from sender
        if (!isSourceNative) {
            TransferHelper.safeTransferFrom(
                address(_from),
                msg.sender,
                address(this),
                amountIn
            );
        }

        // Step 3: Downgrade
        if (_hasUnderlyingFrom) {
            _from.downgrade(amountIn);
        }

        // Step 4: Approve and Swap

        // Encode the path for swap
        bytes memory encodedPath;
        for (uint256 i = 0; i < path.length; i++) {
            if (i == path.length - 1) {
                encodedPath = abi.encodePacked(encodedPath, path[i]);
            } else {
                encodedPath = abi.encodePacked(
                    encodedPath,
                    path[i],
                    poolFees[i]
                );
            }
        }

        // Approve the router to spend token supplied (fromBase).
        approve(IERC20(fromBase), address(swapRouter));

        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter
            .ExactInputParams({
                path: encodedPath,
                recipient: address(this),
                amountIn: IERC20(fromBase).balanceOf(address(this)),
                amountOutMinimum: amountOutMin
            });

        // Execute the swap
        amountOut = swapRouter.exactInput(params);

        // use this if didnt work
        // uint256 toBaseAmount = amountOut // toBase.balanceOf(address(this));

        // Step 5: Upgrade and send tokens back
        approve(IERC20(toBase), address(_to));
        uint toBaseAmount = amountOut;
        if (_hasUnderlyingTo) {
            _to.upgrade(amountOut);
            toBaseAmount = (amountOut * _to.decimals()) / (10 ** ISuperToken(toBase).decimals());
        }

        approve(IERC20(_to), msg.sender);
        TransferHelper.safeTransfer(
            address(_to),
            msg.sender,
            toBaseAmount
        );

        emit SuperSwapComplete(amountOut);
    }
 }
