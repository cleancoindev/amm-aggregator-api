//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./AMMData.sol";

interface IAMM {

    function info() external pure returns(string memory name, uint256 version);

    function addLiquidity(LiquidityToAdd calldata data) external payable;
    function addLiquidityBatch(LiquidityToAdd[] calldata data) external payable;

    function removeLiquidity(LiquidityToRemove calldata data) external;
    function removeLiquidityBatch(LiquidityToRemove[] calldata data) external;

    function swapLiquidity(LiquidityToSwap calldata data) external payable;
    function swapLiquidityBatch(LiquidityToSwap[] calldata data) external payable;
}