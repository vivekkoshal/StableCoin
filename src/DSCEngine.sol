//SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.0;

import{DecnStableCoin} from "../src/DecnStableCoin.sol";
import{ReentrancyGuardUpgradeable} from "../lib/openzeppelin-contracts/contracts/access/ReentrancyGuardUpgradeable.sol";  //this is to prevent reentrant attacks
import{IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol"; //this is for interaction purpose (has a transferfrom function which transfer the token from sender to reciever contract)
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; 


/**
*@title DSCEngine
*@author Vivek Yadav
*this system is designed to be as minimal as possible, and maintains the token as 1token = $1 peg.
*this stablecoin has the properties: Exogeneous (Eth and Btc) , Minting (Algorithmic) , Relative Stability (pegged to USD)
*
*It is similar to DAI if DAI had no governance, no fees and was only backed by wETH and wBTC
*Our DSC system should always be "overcollateralized". At no point, should the  value of all collateral <= backed value of all DSC
*
*@notice This contract is core of DSC system , handels all the logics for mining and redeeming DSC, as well as depositing and withdrawing collateral
*@notice This contract is Very mostly based on MakerDAO DSS (DAI) system
*/

contract DSCEngine is ReentrancyGuardUpgradeable {

     
    ///////////////////
    //errors//////////
    //////////////////   

    error DSCEngine__AmountMustBeMoreThanZero();
    error DSCEngine__TokenAndPriceFeedAdressesMustHaveSameLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsBroken(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorIsOK();
    error DSCEngine__HealthFactorNotImproved();

    ///////////////////
    //State Veriables//
    ////////////////// 

    uint256 private constant LIQUIDATION_THRESHOLD = 50;   //this means you have to be 200% overcollaterilized (if 200 is collateral you cannot mint more than 100 dsc) //collteral should be double
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIDQUIDATION_BONUS = 10; //this mans a 10% bonus on lequdation

    mapping(address token => address priceFeed) private s_priceFeeds;   //token address to pricefeed
    mapping(address user => mapping(address token => uint256 amount)) private s_CollateralDeposited; //this is to record the amount of collateral deposited by user and in which token
    mapping(address user => uint256 amountDscMinted) private s_DscMinted;  //this keep record of the amount of DSC minted by a user

    address[] private s_collateralTokens;       //this is make stuff easy (just for looping)
    DecnStableCoin private immutable i_dsc;

    ///////////////////
    //events//////////
    //////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemeto ,address indexed token, uint256 amount);

    ///////////////////
    //Modifiers///////
    //////////////////

    modifier moreThanZero(uint256 amount){
        if(amount == 0){
            revert DSCEngine__AmountMustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenAddress){
        if(s_priceFeeds[tokenAddress] == address(0)){
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }






    
    ///////////////////
    //functions///////
    //////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses , address dscAddress) {   
        if(tokenAddresses.length != priceFeedAddresses.length){
            revert DSCEngine__TokenAndPriceFeedAdressesMustHaveSameLength();
        }

        //we have to use USD Price Feeds(eg-> ETH/USD , BTC/USD , MKR/USD etc)
        for(uint256 i = 0 ; i < tokenAddresses.length ; i++){
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecnStableCoin(dscAddress);


    }


    /////////////////////
    //Externalfunctions//
    ////////////////////

    /*
    *@param tokenCollateralAddress-> the address of the token we want to deposit(ETH or BTC)
    *@param amountCollteral-> the amount of token we want to deposit
    *@param amountDsctoMint-> the amount of DSC we want to mint
    *@notice this function will deposite your collateral and mint DSC in one transaction
    */
    function depositCollateralAndMintDsc(address tokenCollateralAddress , uint256 amountCollteral ,  uint256 amountDsctoMint) external{
        //this is the combination of depositCollteral and mintDsc functions

        depositCollteral(tokenCollateralAddress , amountCollteral);
        mintDsc(amountDsctoMint);
    }


    /*
    *@param tokenCollateralAddress-> the address of the token we want to deposit(ETH or BTC)
    *@param amountCollteral-> the amount of token we want to deposit
    */
    //this function follows CEI(Checks , Effects , Interactions)
    function depositCollteral(address tokenCollateralAddress , uint256 amountCollteral) public moreThanZero(amountCollteral) isAllowedToken(tokenCollateralAddress) nonReentrant{    //nonReentrant is a modifire defined in ReentrancyGuard  contract to avoid reentrancy attack
    
        s_CollateralDeposited[msg.sender][tokenCollateralAddress] += amountCollteral;  //this updates the amount by user in which token he paid (tokenCollateralAddress)
        emit CollateralDeposited(msg.sender , tokenCollateralAddress , amountCollteral);

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender , address(this) , amountCollteral);  //transfer the token from sender to this contract and returns a boolean (whether the transfer was successful or not)
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }


    /*
    *@param tokenCollateralAddress-> the address of the token we want to redeem(ETH or BTC)
    *@param amountCollteral-> the amount of token we want to redeem
    *@param amountDSCtoBurn-> the amount of DSC we want to burn
    *@notice this function will burn DSC and redeem collateral in one transaction
    */
    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDSCtoBurn) external{ //here we are buring dsc and redeeming collateral at the same time
        burnDSC(amountDSCtoBurn);   //we have to burn the dsc as first so that users can take out there whole amount of collateral if they want to
        redeemCollteral(tokenCollateralAddress , amountCollateral); 
        //no need to check health factor as reedeemcollateral already does this

    }


    //to redeem collateral , health factor must be greater than one after the collateral is pulled out
    function redeemCollteral(address tokenCollateralAddress, uint256 amountCollateral) public moreThanZero(amountCollateral) nonReentrant{

        _redeemCollateral( tokenCollateralAddress , amountCollateral ,msg.sender , msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);   
    }

   // function mintDSC() external{} //done bellow

    function burnDSC(uint256 amount) public moreThanZero(amount){   //if people think that they have more DSC than collateral then can burn DSC to make every thing mainstream
    
        _burnDSC( amount , msg.sender , msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); //this is not needed here are by buring dsc health factor will increase but just of safty we put it here
    
    }
    /*
    *@param amountDsctoMint-> the amount of DSC user to mint(he paid collateral worth 100 dollar but only want to mint DSC worth 20 dollars)
    *@notice they must have more collateral than minimum threshold
    */ 
    function mintDsc(uint256 amountDsctoMint) public moreThanZero(amountDsctoMint) nonReentrant {
        //firstly check if the collateral value > DSC amount
     _revertIfHealthFactorIsBroken(msg.sender);

     s_DscMinted[msg.sender] += amountDsctoMint;

     bool minted = i_dsc.mint(msg.sender , amountDsctoMint);
        if(!minted){
         revert DSCEngine__MintFailed();
        }
    }

    //lets say the threshold is 150% (this means is you have minted (borrowed) $50dsc you have to keep atleast $75ETH as collteral)
    //$100 ETH collteral -> $74 ETH (let the price of ETH falled and 100 eth now worth 74 eth)(but the value of stable coin rarely change)
    //$50DSC  (borrowed 50 DSC by keep the collteral of 100eth)
    //now if price of eth falls This person1 gets UNDERCOLLATERALIZED!!!!

    //person2 -> I will pay back the $50DSC (borrowed amount) - In return he will get (all collteral)$74 ETH [Person 2 Liquidates Person 1(punishment for person 1 too for being undercollateralized)]
    //here person 2 made aprofit of 24 dollars (as me paid 50DSC and got back 74ETh)
    //person1 collteral 100ETH-> 0 ETH  (person2 liquidated person1)
    //person1 has a loss

    //if we are near undercollateralization we need someone to liquidate positions(//intally let 100 eth -> 50 dsc , price falls , later 20 eth -> 50 dsc , we need do liquidate before this condition arrives to avoid system failure(our company loss) )
    //intention -> If someone is almost undercollateralized , we will pay you to liquidate them!!!!!

    /*
    *@pram collateral -> ERC20 collateral addresss to liquidate from the user
    *@pram user -> the user who has boken the health factor(liquidator can chosee) , there health factor should be below MIN_HEALTH_FACTOR
    *@pram debtToCover -> the amount of DSC you(Liquator) want to burn to improve the user health factor
    *@notice -> you(liquidator) can partially liquidate the user.
    *@notice -> you(liquidator) will get a liquidation bonus for taking the users funds
    *@notice -> this function assumes that the protocol is roughly 200% overcollateralized in order for this function to work
    *@notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to incentivise the liquidators to liquidate anyone.
    */ 
    //this function follows CEII -> Checks , Effects , interactions
    function liquidate(address collateral , address user , uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant {
        uint256 startingUserHealthFactor = _healthFactor(user);//first we have to chheck the user is liquidable or not
        if(startingUserHealthFactor >= MIN_HEALTH_FACTOR){
            revert DSCEngine__HealthFactorIsOK();
        }

        //we want to burn their DSC (debt) and their collateral
        //Bad User: $140 ETh , $100 DSC    (debt to cover = 100DSC)
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUSD(collateral , debtToCover);   //we need to return it back to the user by conveting its DSC to ETH
        //also we want to give 100% bonus to the liquidator to incentivise it
        //we are giving lidquidator $110 of weth for 100DSC
        //we should implement a feature to liquidate in the event the protocol is insolvent
        //and add/sweep extra amount into a trasury

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIDQUIDATION_BONUS)/100;
        uint256 tokencollateraltoRedeem = tokenAmountFromDebtCovered + bonusCollateral;
         
        _redeemCollateral(collateral , tokencollateraltoRedeem , user ,msg.sender); //here from is user and to is msg.sender
    
        //we also need to burn DSC
        _burnDSC(debtToCover ,  user , msg.sender); 

        uint256 endingUserHealthFactor = _healthFactor(user);
        if(endingUserHealthFactor <= startingUserHealthFactor){
            revert DSCEngine__HealthFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    
    }

    function gethealthfactor() external view {}


    /////////////////////////////
    //Private&Internl functions//
    ////////////////////////////

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from , address to) private { //this for liquidation purpose so that we can redeem collateral form user and givvve it to liquidator
        
        s_CollateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from , to , tokenCollateralAddress ,amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(to , amountCollateral); //this ierc20 is used to send the tokens, returns a boolean
        if(!success){
            revert DSCEngine__TransferFailed();
        }  
    }
    
    //this is a low level function health factor is creacked in the parent function
    function _burnDSC(uint256 amountDSCtoBurn , address onBehalfOf , address DscFrom) private {
        
      s_DscMinted[onBehalfOf] -= amountDSCtoBurn;
       bool sucess = i_dsc.transferFrom(DscFrom , address(this) , amountDSCtoBurn);  //here we are taking dsc token from the sender address to this contract(DecnStableCoin) address and then burn it using the burn function defined in erc20
       if(!sucess){
         revert DSCEngine__TransferFailed();
        }

        i_dsc.burn(amountDSCtoBurn);
    }

    function _getAccountInformation(address user) private view returns(uint256 totalDscMinted, uint256 CollateralValueUSD ){   
        totalDscMinted = s_DscMinted[user];
        CollateralValueUSD = getAccountCollateralValue(user);
    }




    /*
    *Returns how close the user is to liquidation
    *If a user goes below 1 , then they can get liquidated
    */
    function _healthFactor(address user) private view returns(uint256) {
     //to find this we need //toatal dsc minted and //total collatereal value

     (uint256 totalDscMinted , uint256 CollateralValueUSD) = _getAccountInformation(user);
     uint256 collateralAdjestForThreshold = (CollateralValueUSD * LIQUIDATION_THRESHOLD)/100; 
     
      return ((collateralAdjestForThreshold  * 1e18)/ totalDscMinted); //for not being liquidated it should never do bellow 1
      //eg 150  is our collateral and we minted 100 dsc
      //150*(50(threshold))/100 = 75
      //75/100 = 0.75 < 1 //we can be liquidated (as threshold is 50% , collteral should always be double or more) 


    }

    function _revertIfHealthFactorIsBroken(address user) internal view{
        //1.Check health factor(do they have enough collateral)
        //2. revert if donot have good health factor

        uint256 healthFactor = _healthFactor(user);
        if(healthFactor < 1){
            revert DSCEngine__HealthFactorIsBroken(healthFactor);
        }
    }


    /////////////////////////////
    //Public&External functions//
    ////////////////////////////
    

    function getTokenAmountFromUSD(address token , uint256 USDamountInWei) public view returns(uint256){
        //first we have to get ETH(token Price) ->dollar too Eth
        //eg -> 1eth = 2000usd  -> 1000usd  = 0.5eth

        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price ,,,) = priceFeed.latestRoundData();
        
        return (((USDamountInWei * 1e18) / (uint256(price)* 1e8)) / 1e8);    //price has 8 decimal places pricision

    }


    function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueUSD){ 
        //loop through each collateral token , get the amount they have deposited and map it to the price , to get the USD value

        for(uint256 i = 0 ; i < s_collateralTokens.length ; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_CollateralDeposited[user][token]; // this the amount deposited in that token 
            totalCollateralValueUSD += getUSDValue(token , amount);
        }

        return totalCollateralValueUSD;
    }

    function getUSDValue (address token , uint256 amount) public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price ,,,) = priceFeed.latestRoundData();
        //let 1ETH = 1000USD returned value from the price feed = 1000* 1e8 //we get this 8 decimal place as it is specified in chainlink docs

        // here the amount is in 1e18 format and price is in 1e8;
        //so we need to convert them (we need to do some calculation)
        return ((uint256(price)*1e10) * amount) / 1e18;
    }



}
