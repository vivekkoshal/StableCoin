//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; 

/**
*@title OracleLib
*@author Vivek Yadav
*@notice this libray is used to check ChainLink Oracle for state data(no longer accurate)
*@notice If a price is stale , the function will reveert , and will make the the DSCEngine unsuble - this is by design
*we want DSCEngine to freez if price become stale
*
*COndition ->If the chainLink network exploades and you have a lot of mony lock in the protocol...
*
*/

library OracleLib {


    error OracleLib__StalePrice ();


    uint256 private constant TIMEOUT = 3 hours ;  //in solidity this stands for 3*60*60 = 10800 seconds //this the heatbeat in chaillink website which tells the feed update time in seconds

    function stalePriceCheckLatestRoundData (AggregatorV3Interface priceFeed) public view returns (uint80 , int256 , uint256 , uint256 , uint80) {
        
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

        uint256 secondSince = block.timestamp - updatedAt;   //this will the seconds since the above pricefeed is updated 

        if (secondSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }
        
        return ( roundId,  answer,  startedAt,  updatedAt,  answeredInRound);


    }







}