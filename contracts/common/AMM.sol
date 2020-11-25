//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./IAMM.sol";
import "../util/IERC20.sol";

abstract contract AMM is IAMM {

    mapping(address => uint256) internal _tokenValuesToTransfer;

    receive() external virtual payable {
    }

    function _flushBack(address payable sender, address[] memory tokens, uint256 tokensLength) internal virtual {
        for(uint256 i = 0; i < tokensLength; i++) {
            if(tokens[i] != address(0)) {
                _flushBack(sender, tokens[i]);
            }
        }
        _flushBack(sender, address(0));
    }

    function _flushBack(address payable sender, address tokenA, address tokenB) internal virtual {
        if(tokenA != address(0)) {
            _flushBack(sender, tokenA);
        }
        if(tokenB != address(0)) {
            _flushBack(sender, tokenB);
        }
        _flushBack(sender, address(0));
    }

    function _flushBack(address payable sender, address tokenAddress) internal virtual {
        uint256 balance = tokenAddress == address(0) ? address(this).balance : IERC20(tokenAddress).balanceOf(address(this));

        if(balance == 0) {
            return;
        }

        if(tokenAddress == address(0)) {
            return sender.transfer(balance);
        }

        _safeTransfer(tokenAddress, sender, balance);
    }

    function _transferToMeAndCheckAllowance(LiquidityToAdd memory data, address operator) internal virtual {
        if(!data.tokenAIsETH) {
            _transferToMeAndCheckAllowance(data.tokenA, data.tokenAAmount, operator);
        }
        if(!data.tokenBIsETH) {
            _transferToMeAndCheckAllowance(data.tokenB, data.tokenBAmount, operator);
        }
    }

    function _transferToMeAndCheckAllowance(LiquidityToAdd[] memory data, address operator) internal virtual returns (address[] memory tokens, uint256 length) {
        tokens = new address[](data.length * 2);
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
        }
        _transferToMeCheckAllowanceAndClear(tokens, length, operator);
    }

    function _transferToMeAndCheckAllowance(LiquidityToRemove[] memory data, address operator) internal virtual returns (address[] memory tokens, uint256 length) {
        tokens = new address[](data.length);
        for(uint256 i = 0; i < data.length; i++) {
            if(_tokenValuesToTransfer[data[i].liquidityToken] == 0) {
                tokens[length++] = data[i].liquidityToken;
            }
            _tokenValuesToTransfer[data[i].liquidityToken] += data[i].liquidityAmount;
        }
        _transferToMeCheckAllowanceAndClear(tokens, length, operator);
    }

    function _transferToMeAndCheckAllowance(LiquidityToSwap[] memory data, address operator) internal virtual returns (address[] memory tokens, uint256 length) {
        tokens = new address[](data.length);
        for(uint256 i = 0; i < data.length; i++) {
            if(_tokenValuesToTransfer[data[i].tokens[0]] == 0) {
                tokens[length++] = data[i].tokens[0];
            }
            _tokenValuesToTransfer[data[i].tokens[0]] += data[i].amount;
        }
        _transferToMeCheckAllowanceAndClear(tokens, length, operator);
    }

    function _transferToMeCheckAllowanceAndClear(address[] memory tokens, uint256 length, address operator) internal virtual {
        for(uint256 i = 0; i < length; i++) {
            if(_tokenValuesToTransfer[tokens[i]] > 0) {
                _transferToMeAndCheckAllowance(tokens[i], _tokenValuesToTransfer[tokens[i]], operator);
            }
            delete _tokenValuesToTransfer[tokens[i]];
        }
    }

    function _transferToMeAndCheckAllowance(address tokenAddress, uint256 value, address operator) internal virtual {
        _transferToMe(tokenAddress, value);
        _checkAllowance(tokenAddress, value, operator);
    }

    function _transferToMe(address tokenAddress, uint256 value) internal virtual {
        if(tokenAddress == address(0)) {
            return;
        }
        _safeTransferFrom(tokenAddress, msg.sender, address(this), value);
    }

    function _checkAllowance(address tokenAddress, uint256 value, address operator) internal virtual {
        if(tokenAddress == address(0) || operator == address(0)) {
            return;
        }
        IERC20 token = IERC20(tokenAddress);
        if(token.allowance(address(this), operator) <= value) {
            _safeApprove(tokenAddress, operator, token.totalSupply());
        }
    }

    function _safeApprove(address erc20TokenAddress, address to, uint256 value) internal virtual {
        (bool success, bytes memory data) = erc20TokenAddress.call(abi.encodeWithSelector(IERC20(erc20TokenAddress).approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'APPROVE_FAILED');
    }

    function _safeTransfer(address erc20TokenAddress, address to, uint256 value) internal virtual {
        (bool success, bytes memory data) = erc20TokenAddress.call(abi.encodeWithSelector(IERC20(erc20TokenAddress).transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }

    function _safeTransferFrom(address erc20TokenAddress, address from, address to, uint256 value) internal virtual {
        (bool success, bytes memory data) = erc20TokenAddress.call(abi.encodeWithSelector(IERC20(erc20TokenAddress).transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFERFROM_FAILED');
    }

    function _sortTokens(IERC20 tokenA, IERC20 tokenB) internal virtual pure returns(IERC20, IERC20) {
        if (tokenA < tokenB) {
            return (tokenA, tokenB);
        }
        return (tokenB, tokenA);
    }

}