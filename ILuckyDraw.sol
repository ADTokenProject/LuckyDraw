//SPDX-License-Identifier: MIT
pragma solidity >= 0.6.0 < 0.8.0;

interface ILuckyDraw {

    function numbersDrawn(
        uint256 _luckyDrawId,
        bytes32 _requestId,
        uint256 _randomNumber
    )
    external;
}