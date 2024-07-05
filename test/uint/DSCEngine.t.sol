//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import{Test} from "forge-std/Test.sol";
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

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;



    function setUp() public {
        deployer = new DeployDSC();
        (DSC, Engine , config) = deployer.run();
        (ethUsdPriceFeed, , weth, , ) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE ); //here we are giving 10 ether to user
    }

    

    //Price Tests//

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18; //lets we have 15 eth
        //15e18 * 2000/ETH = 30000e18;
        uint256 expectedUsdValue = 30000e18;
        uint256 actualUsdValue = Engine.getUSDValue(weth, ethAmount); //internally it uses the price feed associate with that function
        assertEq(expectedUsdValue, actualUsdValue);
    }

    //deposit Collteral Tests//

    function testRevertsIfCollteralisZero() public {
        vm.startPrank(USER);

        /*here this line is of no use can also be commented out*/ERC20Mock(weth).approve(address(Engine) , AMOUNT_COLLATERAL);//here the owner is user and it approves 10ether to Engine to spend

        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        Engine.depositCollteral(weth, 0);  //this will revert as user is depositing 0 amount
        vm.stopPrank();

    }

}