//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import{Test, console} from "forge-std/Test.sol";
import{DeployDSC} from "../../script/DeployDSC.s.sol";
import{DSCEngine} from "../../src/DSCEngine.sol";
import{DecnStableCoin} from "../../src/DecnStableCoin.sol";
import{HelperConfig} from "../../script/HelperConfig.s.sol";
import{ERC20Mock} from "../../test/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    
    DeployDSC deployer;
    DSCEngine Engine;
    DecnStableCoin DSC;
    HelperConfig config;

    address ethUsdPriceFeed;
    address weth;
    address btcUsdPriceFeed;
    address wbtc;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 100 ether;
    uint256 public constant amountToMint = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 100 ether;



    function setUp() public {
        deployer = new DeployDSC();
        (DSC, Engine , config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc , ) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE ); //here we are giving 10 ether to user
    }

    //contructor Tests//

    address[] public tokenAdress;
    address[] public priceFeedAdress;
    function testRevertIfTokenLengthDoesnotMatchPricefeed() public {
        tokenAdress.push(weth);
        priceFeedAdress.push(ethUsdPriceFeed);
        priceFeedAdress.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAndPriceFeedAdressesMustHaveSameLength.selector);
        new DSCEngine(tokenAdress , priceFeedAdress , address(DSC));

        
    }

    //Price Tests//

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18; //lets we have 15 eth
        //15e18 * 2000/ETH = 30000e18;
        uint256 expectedUsdValue = 30000e18;
        uint256 actualUsdValue = Engine.getUSDValue(weth, ethAmount); //internally it uses the price feed associate with that function
        assertEq(expectedUsdValue, actualUsdValue);
    }

    function testgetTokenAmountFromUSD() public {
        uint256 usdAmount = 100 ether;
        //2000/eth -> 100 usd = 0.05 ether
        uint256 expectedTokenAmount = 0.05 ether;
        uint256 actualTokenAmount = Engine.getTokenAmountFromUSD(weth, usdAmount);
        assertEq(expectedTokenAmount, actualTokenAmount);    
    }


    //deposit Collteral Tests//

    function testRevertsIfCollteralisZero() public {
        vm.startPrank(USER);

        /*here this line is of no use can also be commented out*/ERC20Mock(weth).approve(address(Engine) , AMOUNT_COLLATERAL);//here the owner is user and it approves 10ether to Engine to spend

        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        Engine.depositCollteral(weth, 0);  //this will revert as user is depositing 0 amount
        vm.stopPrank();

    }

    function testRevertWithUnallowedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN" , USER ,AMOUNT_COLLATERAL); //here we made a mock token like btc or eth and gave it to the user (10 ether)

        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        Engine.depositCollteral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
    
    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(Engine) , AMOUNT_COLLATERAL);//here the owner is user and it approves 10ether to Engine to spend
        Engine.depositCollteral(weth, AMOUNT_COLLATERAL); //here the amount is deposited
        vm.stopPrank();
        _;
       
    }

    function testCanDepositeCollateralAndgetAccountInfo() public depositedCollateral {
        (uint256 toatalDSCMinted , uint256 collateralValueInUsd) = Engine.getAccountInformation(USER);

        uint256 expectedTotalDSCMinted = 0;
        uint256 expectedCollateralValueInUsd = Engine.getUSDValue(weth, AMOUNT_COLLATERAL);
        assertEq(expectedTotalDSCMinted, toatalDSCMinted);
        assertEq(expectedCollateralValueInUsd, collateralValueInUsd);
    }

    //ToDO: add more tests   //make a calucate health factor
    
      function testCanMintDsc() public depositedCollateral {
        vm.prank(USER);
        Engine.mintDsc(amountToMint);

        uint256 userBalance = DSC.balanceOf(USER);
        uint256 tokenWithUser = Engine.getTotalTokenSupply(USER);
        console.log("this is the dsc he has " , userBalance);
        console.log("this is the no of token with him" , tokenWithUser);
        assertEq(userBalance, amountToMint);
    }


}