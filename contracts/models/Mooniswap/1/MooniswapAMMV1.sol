//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./IMooniswapAMMV1.sol";
import "../../../common/AMM.sol";

contract MooniswapAMMV1 is IMooniswapAMMV1, AMM {

    address private immutable _mooniFactoryAddress;

    constructor(address mooniFactoryAddress) {
        _mooniFactoryAddress = mooniFactoryAddress;
    }

    function factory() public virtual override view returns(address) {
        return _mooniFactoryAddress;
    }

    function info() public virtual override pure returns(string memory name, uint256 version) {
        return ("MooniswapAMM", 1);
    }

    function addLiquidity(LiquidityToAdd memory data) public payable virtual override {
        Mooniswap mooniswap = _getOrCreateMooniswap(data.tokenA, data.tokenB, data.tokenAIsETH, data.tokenBIsETH, data.tokenAAmount, data.tokenBAmount);
        _addLiquidityWork(data, mooniswap);
        _flushBack(msg.sender, data.tokenA, data.tokenB);
    }

    function addLiquidityBatch(LiquidityToAdd[] memory data) public payable virtual override {
        (address[] memory tokens, uint256 tokensLength) = _transferToMeAndCheckAllowance(data, address(0));
        for(uint256 i = 0; i < data.length; i++) {
            _addLiquidityWork(data[i], _getOrCreateMooniswap(data[i].tokenA, data[i].tokenB, data[i].tokenAIsETH, data[i].tokenBIsETH, data[i].tokenAAmount, data[i].tokenBAmount));
        }
        _flushBack(msg.sender, tokens, tokensLength);
    }

    function _getOrCreateMooniswap(address token0, address token1, bool token0IsETH, bool token1IsETH, uint256 token0Amount, uint256 token1Amount) private returns (Mooniswap mooniswap) {
        mooniswap = IMooniFactory(_mooniFactoryAddress).pools(IERC20(token0IsETH ? address(0) : token0), IERC20(token1IsETH ? address(0) : token1));
        if(address(mooniswap) == address(0)) {
            mooniswap = IMooniFactory(_mooniFactoryAddress).deploy(IERC20(token0IsETH ? address(0) : token0), IERC20(token1IsETH ? address(0) : token1));
        }
        if(!token0IsETH) {
            _transferToMeAndCheckAllowance(token0, token0Amount, address(mooniswap));
        }
        if(!token1IsETH) {
            _transferToMeAndCheckAllowance(token1, token1Amount, address(mooniswap));
        }
    }

    function _transferToMeAndCheckAllowance(LiquidityToAdd[] memory data) private returns(address[] memory tokens, uint256 length, Mooniswap[] memory mooniswap) {
        tokens = new address[](data.length * 2);
        mooniswap = new Mooniswap[](data.length);
        for(uint256 i = 0; i < data.length; i++) {
            if(data[i].tokenA != address(0) && !data[i].tokenAIsETH) {
                if(_tokenValuesToTransfer[data[i].tokenA] == 0) {
                    tokens[length++] = data[i].tokenA;
                }
                _tokenValuesToTransfer[data[i].tokenA] += data[i].tokenAAmount;
            }
            if(data[i].tokenB != address(0) && data[i].tokenBIsETH) {
                if(_tokenValuesToTransfer[data[i].tokenB] == 0) {
                    tokens[length++] = data[i].tokenB;
                }
                _tokenValuesToTransfer[data[i].tokenB] += data[i].tokenBAmount;
            }
            mooniswap[i] = _getOrCreateMooniswap(data[i].tokenA, data[i].tokenB, data[i].tokenBIsETH, data[i].tokenBIsETH, data[i].tokenAAmount, data[i].tokenBAmount);
        }
    }

    function _addLiquidityWork(LiquidityToAdd memory data, Mooniswap mooniswap) internal virtual {
        require(data.receiver != address(0), "Receiver cannot be void address");
        (IERC20 t1, IERC20 t2) = _sortTokens(IERC20(data.tokenAIsETH ? address(0) : data.tokenA), IERC20(data.tokenBIsETH ? address(0) : data.tokenB));
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = t1;
        tokens[1] = t2;
        uint256[] memory minAmounts = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = address(t1) == (data.tokenAIsETH ? address(0) : data.tokenA) ? data.tokenAAmount : data.tokenBAmount;
        amounts[1] = address(t2) == (data.tokenBIsETH ? address(0) : data.tokenB) ? data.tokenBAmount : data.tokenAAmount;

        if(!data.tokenAIsETH && !data.tokenBIsETH) {
            mooniswap.deposit(amounts, minAmounts);
        } else {
            mooniswap.deposit{value : data.tokenAIsETH ? data.tokenAAmount : data.tokenBAmount}(amounts, minAmounts);
        }
        _flushBack(payable(data.receiver), address(mooniswap));
    }

    function removeLiquidity(LiquidityToRemove memory data) public virtual override {
        _transferToMeAndCheckAllowance(data.liquidityToken, data.liquidityAmount, address(0));
        _removeLiquidityWork(data);
        _flushBack(msg.sender, data.liquidityToken);
    }

    function removeLiquidityBatch(LiquidityToRemove[] memory data) public virtual override {
        (address[] memory tokens, uint256 tokensLength) = _transferToMeAndCheckAllowance(data, address(0));
        for(uint256 i = 0; i < data.length; i++) {
            _removeLiquidityWork(data[i]);
        }
        _flushBack(msg.sender, tokens, tokensLength);
    }

    function _removeLiquidityWork(LiquidityToRemove memory data) internal virtual {
        require(data.receiver != address(0), "Receiver cannot be void address");
        Mooniswap mooniswap = Mooniswap(data.liquidityToken);
        mooniswap.withdraw(data.liquidityAmount, new uint256[](2));
        IERC20[] memory tokens = mooniswap.getTokens();
        for(uint256 i = 0 ; i < tokens.length; i++) {
            _flushBack(payable(data.receiver), address(tokens[i]));
        }
    }

    function swapLiquidity(LiquidityToSwap memory data) public payable virtual override {
        _transferToMeAndCheckAllowance(data.tokens[0], data.amount, address(0));
        _swapLiquidityWork(data);
        _flushBack(msg.sender, data.tokens, data.tokens.length);
    }

    function swapLiquidityBatch(LiquidityToSwap[] memory data) public payable virtual override {
        (address[] memory tokens, uint256 tokensLength) = _transferToMeAndCheckAllowance(data, address(0));
        for(uint256 i = 0; i < data.length; i++) {
            _swapLiquidityWork(data[i]);
        }
        _flushBack(msg.sender, tokens, tokensLength);
    }

    function _swapLiquidityWork(LiquidityToSwap memory data) internal virtual {
        require(data.receiver != address(0), "Receiver cannot be void address");
        
    }
}