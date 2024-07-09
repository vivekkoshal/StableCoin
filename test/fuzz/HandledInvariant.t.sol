//SPDX-License-Identifier: MIT

//here we will use handled methods to narrow down the function calls

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
import{Handler} from "./Handler.t.sol";

contract HandledInvariantTest is StdInvariant, Test { 

    DeployDSC deployer;
    DSCEngine Engine;
    DecnStableCoin DSC;
    HelperConfig config;
    address weth;
    address wbtc;

    Handler handler;

    function setUp() external{ 
        deployer = new DeployDSC();
        (DSC, Engine , config) = deployer.run();
        (,, weth, wbtc, ) = config.activeNetworkConfig();
       // targetContract(address(Engine)); ->this is for open testing

        handler = new Handler(Engine, DSC);
        targetContract(address(handler));

        //here we will do everything in handled way(using handler)
        //hey, donot call redeemcollateral ,unless there is collateral to redeem

    }
    
    function invariant_MustHaveMoreValueThanTheTotalSupply() public view {
        //get the value of all the collateral in the protocol
        //compare it to all the debt(dsc)

        uint256 totalSupply = DSC.totalSupply(); //total supply is a global variale -> it gives the total supply of dsc in the entire world(here only was to mint DSC is the DSCEngin)
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(Engine)); //this gives total amount of weth deposited in that contract
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(Engine)); //this gives total amount of wbtc deposited in that contract

        uint256 wethValue = Engine.getUSDValue(weth, totalWethDeposited);
        uint256 wbtcValue = Engine.getUSDValue(wbtc, totalBtcDeposited);

        console.log("hi i am hereeeeeeeeeeeeeeee!!!!!!!!!!!");
        console.log("weth value", wethValue);
        console.log("wbtc value", wbtcValue);
        console.log("total supply", totalSupply);
        console.log("times Minted is called", handler.timesMintIsCalled());
        console.log("amount passed to mint" , handler.amountToMint());


        assert(totalSupply <= (wethValue + wbtcValue));   //this test will fail as some random function calls mint the dsc and some random function calls will deposite amount
    }

    //test no getter should revert 
    function invariant_getterViewFunctionShouldNeverRevert() public view {
    //   //we have to just call our all  getter functions
    //     Engine.gethealthfactor();
    //     Engine.getCollateralTokens();

    //forge inspect DSCEngine methods -> gives all the functions in the contract
    }
}