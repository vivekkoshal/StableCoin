// SPDX-License-Identifier: MIT 

//Handler is going to narrow down the way we call function(donot waste time on function call which are not used)
//the functions defined in the handler will only run randomly
pragma solidity ^0.8.18;

import{Test} from "forge-std/Test.sol";
import{DSCEngine} from "../../src/DSCEngine.sol";
import{DecnStableCoin} from "../../src/DecnStableCoin.sol";
import{ERC20Mock} from "../../test/mocks/ERC20Mock.sol";
import{MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {

    DSCEngine Engine;
    DecnStableCoin DSC;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintIsCalled ; //this is used for debugging purpose
    uint256 public amountToMint;
    address[] public UserWithCollateralDeposited;  //this is to keep record of the user who have deposited collateral and they can only mint dsc
    MockV3Aggregator public ethUsdPriceFeed;

    uint256 MAX_DEOSIT_SIZE = type(uint96).max;  //this will give the max uint96 value

    constructor(DSCEngine _Engine, DecnStableCoin _DSC) {
        Engine = _Engine;
        DSC = _DSC;

        address[] memory collateraltokenAdr = Engine.getCollateralTokens();
        weth = ERC20Mock(collateraltokenAdr[0]);
        wbtc = ERC20Mock(collateraltokenAdr[1]);

        ethUsdPriceFeed = MockV3Aggregator(Engine.getCollateralTokenPriceFeed(address(weth)));  //this will be used to change the price feed of weth
    }

    //redeem collateral ->hey, donot call redeemcollateral ,unless there is collateral to redeem

    function depositCollateral(uint256 collateralSeed , uint256 amountCollateral) public {  //here instead of passing random collateral address we will only pass valid collateral address
        
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral , 1 , MAX_DEOSIT_SIZE );  //bound is a function defined in forge std library  //as it will revert if the amount is 0 with an error  DSCEngine__AmountMustBeMoreThanZero

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(Engine), amountCollateral);
        Engine.depositCollteral(address(collateral), amountCollateral);  //this will revert as we are passing random collateral addresses
        
        UserWithCollateralDeposited.push(msg.sender); //error ->this can also double push some user as they are random
        vm.stopPrank();
    }

    function redeemtheCollateral(uint256 collateralSeed , uint256 amountCollateral) public {  

        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = Engine.getCollateralBalanceOfUSer(msg.sender , address(collateral));

        amountCollateral = bound(amountCollateral , 0 , maxCollateralToRedeem );
        if(amountCollateral ==0){
            return;
        }
        Engine.redeemCollteral(address(collateral), amountCollateral);

    }
    
    function mintDSC(uint256 amount , uint256 addressSeed) public{
        //amount = bound(amount , 1 , MAX_DEOSIT_SIZE);

        if(UserWithCollateralDeposited.length == 0){
            return;
        }
        address sender = UserWithCollateralDeposited[addressSeed % UserWithCollateralDeposited.length];


       
        vm.startPrank(sender);
        (uint256 totalDscMinted , uint256 CollateralValueUSD) = Engine.getAccountInformation(sender);
        
         

        int256 maxDsctoMint = (int256(CollateralValueUSD) / 2) - int256(totalDscMinted);  //this will give the max DSC that the user can mint currently
        if(maxDsctoMint < 0){
            return;
        }
        //timesMintIsCalled++;
       
        
        amount = bound(amount , 0 , uint256(maxDsctoMint));
        if(amount ==0){
            return;
        }
        amountToMint = amount;

        
        Engine.mintDsc(amount);
        vm.stopPrank();

        timesMintIsCalled++;
    }


    ///this function can break out inverant as the price will fall rapildly and we donot have any liquidator function
    // function updateCollateralPrice(uint96 newPrice) public{
    
    // int256 newPriceInt = int256(uint256(newPrice)); //to convert uint96 to int256 we have to first wrap it into uint256 and then into int256
    // ethUsdPriceFeed.updateAnswer(newPriceInt); //this will update the price feed( defined in mock V3 Aggregator)
    
    // }




    //helper Function

    //this function only gives the valid collateral token addreses
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        
        if(collateralSeed % 2 == 0){
            return weth;
        }

        return wbtc;
    }



}






