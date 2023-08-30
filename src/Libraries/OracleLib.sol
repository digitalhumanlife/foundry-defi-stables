// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/**
 * @title OracleLib
 * @author JW
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * If a price is stale, the fucntion will revert, and render the DSCEngine unusable(Freeze the DSCEngine)
 * So if the chainlink network is down, the money will be locked in the DSCEngine.
 */

library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours; // 3 * 60 * 60 = 10800 seconds

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();
        uint256 secondsPassedSinceLastUpdate = block.timestamp - updatedAt;
        if (secondsPassedSinceLastUpdate > TIMEOUT) revert OracleLib__StalePrice();
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
