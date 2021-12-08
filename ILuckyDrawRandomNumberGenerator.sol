//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface ILuckyDrawRandomNumberGenerator {

    /** 
     * Requests randomness
     */
    function getRandomNumber(
        uint256 luckyDrawId)
    external
    returns (bytes32 requestId);
}