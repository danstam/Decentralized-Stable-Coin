// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

/**
 * @title DeployDSC
 * @dev This contract deploys the DecentralizedStableCoin and DSCEngine contracts.
 * It fetches network configuration from the HelperConfig contract, deploys the two main contracts,
 * and sets up their relationship. The ownership of the DecentralizedStableCoin contract is transferred
 * to the DSCEngine contract. The `run()` function performs these operations and returns instances of the deployed contracts.
 */

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run()
        external
        returns (DecentralizedStableCoin, DSCEngine, HelperConfig)
    {
        HelperConfig config = new HelperConfig();

        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = config.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin stableCoin = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(stableCoin)
        );
        stableCoin.transferOwnership(address(engine));

        vm.stopBroadcast();
        return (stableCoin, engine, config);
    }
}
