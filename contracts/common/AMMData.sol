//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

struct LiquidityToAdd {
    address tokenA;
    uint256 tokenAAmount;
    uint256 tokenAMinimumAmount;
    bool tokenAIsETH;
    address tokenB;
    uint256 tokenBAmount;
    uint256 tokenBMinimumAmount;
    bool tokenBIsETH;
    address receiver;
}

struct LiquidityToRemove {
    address liquidityToken;
    uint256 liquidityAmount;
    bool ethInvolved;
    address receiver;
}

struct LiquidityToSwap {
    bool enterInETH;
    bool exitInETH;
    address[] tokens;
    uint256 amount;
    address receiver;
}