//SPDX-License-Identifier: MIT


//what are our inverants
//1. the total supply of DSC should be less than the total value of the collateral
//2. Getter view functions should never revert <- evergreen invariants


pragma solidity ^0.8.18;

import{Test , console} from "forge-std/Test.sol";
import{StdInvariant} from "forge-std/StdInvariant.sol";
import{DeployDSC} from "../../script/DeployDSC.s.sol";
import{DSCEngine} from "../../src/DSCEngine.sol";
import{DecnStableCoin} from "../../src/DecnStableCoin.sol";
import{HelperConfig} from "../../script/HelperConfig.s.sol";
import{IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract OpenInvertiantsTest is StdInvariant, Test {

    DeployDSC deployer;
    DSCEngine Engine;
    DecnStableCoin DSC;
    HelperConfig config;
    address weth;
    address wbtc;

    function setUp() external{ 
        deployer = new DeployDSC();
        (DSC, Engine , config) = deployer.run();
        (,, weth, wbtc, ) = config.activeNetworkConfig();
        targetContract(address(Engine));  //this is open testing we are just telling foundary to go wild on this contract
    }
    
    function invariant_protocolMustHaveMoreValueThanTheTotalSupply() public view {
        //get the value of all the collateral in the protocol
        //compare it to all the debt(dsc)

        //uint256 totalSupply = DSC.totalSupply(); //total supply is a global variale -> it gives the total supply of dsc in the entire world(here only was to mint DSC is the DSCEngin)
        uint256 totalSupply =  DSC.totalSupply();//this is not a global variable, gives total amount of dsc minted
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(Engine)); //this gives total amount of weth deposited in that contract
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(Engine)); //this gives total amount of wbtc deposited in that contract

        uint256 wethValue = Engine.getUSDValue(weth, totalWethDeposited);
        uint256 wbtcValue = Engine.getUSDValue(wbtc, totalBtcDeposited);

        console.log("hi i am hereeeeeeeeeeeeeeee!!!!!!!!!!!");
        console.log("weth value", wethValue);
        console.log("wbtc value", wbtcValue);
        console.log("total supply", totalSupply);


        assert(totalSupply <= (wethValue + wbtcValue));
        //this test will revert most of the time as its randomly hits functions and do minting ect stuff
    }
}