// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import{Script} from "forge-std/Script.sol";
import{MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import{ERC20Mock} from "../test/mocks/ERC20Mock.sol";


contract HelperConfig is Script{

    struct NetworkConfig{
        address wethUsdPriceFeed;   //weth(w) are the erc20 version of eth or btc
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 DeployerKey;
    }

    uint8 public constant decimals = 8;  //used as input in mockaggregatorv3 interface
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public Default_Anvil_Private_key =0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor(){
        if(block.chainid == 11155111){
            activeNetworkConfig = getSepoliaConfig();
        }
        else{
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaConfig() public view returns(NetworkConfig memory){

        return NetworkConfig({wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43, weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81, wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, DeployerKey: 0x7ac3722a9d4906966d021dfe1536f82a9d778937ce18f3b3704f04b1ed116f39}); //weth and wbtc are made and deployed by patric on etherscan
    }


    function getOrCreateAnvilEthConfig() public  returns(NetworkConfig memory){
        if(activeNetworkConfig.wethUsdPriceFeed != address(0)){ //we had already seted it
            return activeNetworkConfig;
        }
        //for broadcasting we need couple of mocks (mocks pricefeed and mock token address)
        vm.startBroadcast();

        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(decimals, ETH_USD_PRICE);
        MockV3Aggregator wbtcUsdPriceFeed = new MockV3Aggregator(decimals, BTC_USD_PRICE);

        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender , 1000e8); //1000e8 is the intial amount in that(msg.sender) address
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender , 1000e8);

        vm.stopBroadcast();

        return NetworkConfig({wethUsdPriceFeed: address(ethUsdPriceFeed), wbtcUsdPriceFeed: address(wbtcUsdPriceFeed), weth: address(wethMock), wbtc: address(wbtcMock), DeployerKey:  Default_Anvil_Private_key});
    }


}