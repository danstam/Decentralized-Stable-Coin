// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/Mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

/**
 * @title Helper Configuration
 * @dev The HelperConfig contract is a central hub for managing and accessing key network-specific configurations within the system. 

It simplifies the process of dealing with different network settings, such as addresses of key contracts and price feeds, by providing a single point of reference. This allows other parts of the system to operate consistently across different networks without needing to know the specific details of each network.

A significant feature of this contract is its ability to aid in testing. When the system operates on the Anvil Ethereum network, the contract deploys MockV3Aggregator contracts for the price feeds. These mock contracts mimic the behavior of actual price feeds, similar to a flight simulator for pilots. This feature allows us to test the system's response to various price scenarios without the need to interact with real-world price data, ensuring robustness and reliability of the system.


 */

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
                wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
                weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
                wbtc: 0xFF82bB6DB46Ad45F017e2Dfb478102C7671B13b3,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wbtcUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            ETH_USD_PRICE
        );
        ERC20Mock wethMock = new ERC20Mock();

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );
        ERC20Mock wbtcMock = new ERC20Mock();
        vm.stopBroadcast();
        return
            NetworkConfig(
                address(ethUsdPriceFeed),
                address(btcUsdPriceFeed),
                address(wethMock),
                address(wbtcMock),
                DEFAULT_ANVIL_PRIVATE_KEY
            );
    }
}
