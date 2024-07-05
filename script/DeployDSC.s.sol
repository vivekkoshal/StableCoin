// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import{Script} from "forge-std/Script.sol";
import{DecnStableCoin} from "../src/DecnStableCoin.sol";
import{DSCEngine} from "../src/DSCEngine.sol";
import{HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {

    address[] public tokenAddresses;
    address[] public PriceFeedAddresses;

    function run() external returns(DecnStableCoin, DSCEngine , HelperConfig) {

        HelperConfig helperconfig = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 DeployerKey) = helperconfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        PriceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];


        vm.startBroadcast();
        DecnStableCoin DSC = new DecnStableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses, PriceFeedAddresses, address(DSC) );

        DSC.transferOwnership(address(engine));      //here we tranfer the ownership now only dsc engin can mint or burn coins  

        vm.stopBroadcast();

        return (DSC, engine , helperconfig);
    }


}