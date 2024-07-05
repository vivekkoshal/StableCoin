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

import{ERC20Burnable, ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import{Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
//ownable gives owner exclusive rights to certain functions 

/**
*@title DecnStableCoin
*@author Vivek Yadav
*collateral : Exogeneous (Eth and Btc)
*Minting : Algorithmic
*Relative Stability : pegged to US Dollar
*this token is ment to be governed by DSCEngin. This contract is just a ERC20 implementation of our stable coin system.
*/

contract DecnStableCoin is ERC20Burnable , Ownable{   //erc20buranble is erc20 so we have to import both of them

    error DecnStableCoin__MustBeMoreThanZero();
    error DecnStableCoin__BurnAmountExceedsBalance();
    error DecnStableCoin__TransferToZeroAddress();


    constructor() ERC20("DecnStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 amount) public override onlyOwner{  //onlyOwner function is specified in the ownable contract
        uint256 balance = balanceOf(msg.sender);

        if(amount <= 0){
            revert DecnStableCoin__MustBeMoreThanZero();
        }

        if(balance < amount){
            revert DecnStableCoin__BurnAmountExceedsBalance();
        }

        super.burn(amount);    //super key word means(use the burn function from parent class(erc20burnable))
        //here we called super because we were overriding the burn function(first do my burn function than do regular burn)
    }

    function mint(address _to , uint256 _amount) external onlyOwner returns(bool){ 

        if(_to == address(0)){
            revert DecnStableCoin__TransferToZeroAddress();
        }
        if(_amount <= 0){
            revert DecnStableCoin__MustBeMoreThanZero();
        }
        
        _mint(_to, _amount); //here we didnot called super there is no mint fuction its _mint() so we are not overriding

        return true;
    }




}