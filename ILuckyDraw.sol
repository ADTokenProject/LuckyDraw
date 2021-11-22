//SPDX-License-Identifier: MIT
pragma solidity >= 0.6.0 < 0.8.0;

interface ILuckyDraw {

    //-------------------------------------------------------------------------
    // VIEW FUNCTIONS
    //-------------------------------------------------------------------------

    function getPlayerLength(  uint256 _luckyDrawId) external view returns(uint256);

    //-------------------------------------------------------------------------
    // STATE MODIFYING FUNCTIONS
    //-------------------------------------------------------------------------

    function numbersDrawn(
        uint256 _luckyDrawId,
        bytes32 _requestId,
        uint256 _randomNumber
    )
    external;
}