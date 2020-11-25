//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./IUniswapV2AMMV1.sol";
import "../../../common/AMM.sol";

contract UniswapV2AMMV1 is IUniswapV2AMMV1, AMM {

    address private immutable _uniswapV2RouterAddress;

    address private immutable _wethAddress;

    address private immutable _factoryAddress;

    constructor(address uniswapV2RouterAddress) {
        _wethAddress = IUniswapV2Router(_uniswapV2RouterAddress = uniswapV2RouterAddress).WETH();
        _factoryAddress = IUniswapV2Router(uniswapV2RouterAddress).factory();
    }

    function router() public virtual override view returns(address) {
        return _uniswapV2RouterAddress;
    }

    function wethAddress() public virtual override view returns(address) {
        return _wethAddress;
    }

    function info() public virtual override pure returns(string memory name, uint256 version) {
        return ("UniswapV2AMM", 1);
    }

    function addLiquidity(LiquidityToAdd memory data) public payable virtual override {
        _transferToMeAndCheckAllowance(data, _uniswapV2RouterAddress);
        _addLiquidityWork(data);
        _flushBack(msg.sender, data.tokenA, data.tokenB);
    }

    function addLiquidityBatch(LiquidityToAdd[] memory data) public payable virtual override {
        (address[] memory tokens, uint256 tokensLength) = _transferToMeAndCheckAllowance(data, _uniswapV2RouterAddress);
        for(uint256 i = 0; i < data.length; i++) {
            _addLiquidityWork(data[i]);
        }
        _flushBack(msg.sender, tokens, tokensLength);
    }

    function _addLiquidityWork(LiquidityToAdd memory data) internal virtual {
        require(data.receiver != address(0), "Receiver cannot be void address");
        if(!data.tokenAIsETH && !data.tokenBIsETH) {
            IUniswapV2Router(_uniswapV2RouterAddress).addLiquidity(
                data.tokenA,
                data.tokenB,
                data.tokenAAmount,
                data.tokenAAmount,
                data.tokenAMinimumAmount,
                data.tokenBMinimumAmount,
                data.receiver,
                block.timestamp + 10000
            );
        } else {
            address token = data.tokenAIsETH ? data.tokenB : data.tokenA;
            uint256 amountTokenDesired = data.tokenAIsETH ? data.tokenBAmount : data.tokenAAmount;
            uint256 amountTokenMin = data.tokenAIsETH ? data.tokenAMinimumAmount : data.tokenAMinimumAmount;
            uint256 amountETHDesired = data.tokenAIsETH ? data.tokenAAmount : data.tokenBAmount;
            uint256 amountETHMin = data.tokenAIsETH ? data.tokenAMinimumAmount : data.tokenAMinimumAmount;
            IUniswapV2Router(_uniswapV2RouterAddress).addLiquidityETH {value : amountETHDesired} (
                token,
                amountTokenDesired,
                amountTokenMin,
                amountETHMin,
                data.receiver,
                block.timestamp + 10000
            );
        }
    }

    function removeLiquidity(LiquidityToRemove memory data) public virtual override {
        _transferToMeAndCheckAllowance(data.liquidityToken, data.liquidityAmount, _uniswapV2RouterAddress);
        _removeLiquidityWork(data);
        _flushBack(msg.sender, data.liquidityToken);
    }

    function removeLiquidityBatch(LiquidityToRemove[] memory data) public virtual override {
        (address[] memory tokens, uint256 tokensLength) = _transferToMeAndCheckAllowance(data, _uniswapV2RouterAddress);
        for(uint256 i = 0; i < data.length; i++) {
            _removeLiquidityWork(data[i]);
        }
        _flushBack(msg.sender, tokens, tokensLength);
    }

    function _removeLiquidityWork(LiquidityToRemove memory data) internal virtual {
        require(data.receiver != address(0), "Receiver cannot be void address");
        address token0 = IUniswapV2Pair(data.liquidityToken).token0();
        address token1 = IUniswapV2Pair(data.liquidityToken).token1();
        if(!data.ethInvolved) {
            IUniswapV2Router(_uniswapV2RouterAddress).removeLiquidity(token0, token1, data.liquidityAmount, 1, 1, data.receiver, block.timestamp + 1000);
        } else {
            IUniswapV2Router(_uniswapV2RouterAddress).removeLiquidityETH(token0 != _wethAddress ? token0 : token1, data.liquidityAmount, 1, 1, data.receiver, block.timestamp + 1000);
        }
    }

    function swapLiquidity(LiquidityToSwap memory data) public payable virtual override {
        _transferToMeAndCheckAllowance(data.tokens[0], data.amount, _uniswapV2RouterAddress);
        _swapLiquidityWork(data);
        _flushBack(msg.sender, data.tokens, data.tokens.length);
    }

    function swapLiquidityBatch(LiquidityToSwap[] memory data) public payable virtual override {
        (address[] memory tokens, uint256 tokensLength) = _transferToMeAndCheckAllowance(data, _uniswapV2RouterAddress);
        for(uint256 i = 0; i < data.length; i++) {
            _swapLiquidityWork(data[i]);
        }
        _flushBack(msg.sender, tokens, tokensLength);
    }

    function _swapLiquidityWork(LiquidityToSwap memory data) internal virtual {
        require(data.receiver != address(0), "Receiver cannot be void address");
        if(!data.enterInETH && !data.exitInETH) {
            IUniswapV2Router(_uniswapV2RouterAddress).swapExactTokensForTokens(data.amount, 1, data.tokens, data.receiver, block.timestamp + 1000);
            return;
        }
        if(data.enterInETH) {
            IUniswapV2Router(_uniswapV2RouterAddress).swapExactETHForTokens{value : data.amount}(1, data.tokens, data.receiver, block.timestamp + 1000);
            return;
        }
        if(data.exitInETH) {
            IUniswapV2Router(_uniswapV2RouterAddress).swapExactTokensForETH(data.amount, 1, data.tokens, data.receiver, block.timestamp + 1000);
            return;
        }
    }
}