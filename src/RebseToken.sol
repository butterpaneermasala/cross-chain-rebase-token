// SPDX-Lincese-Identifier: MIT

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


pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Rebase Token
 * @author Satya Pradhan
 * @notice This is a cross-chain rebase token that incentivies users to desposit into a vault and get interests in reward.
 * @notice The interest rate in this smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
 * 
 */


contract RebaseToken is ERC20 {
    ///////////////////////
    /// Errors ///
    ///////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 newInterestRate, uint256 oldInterestRate);
    ///////////////////////
    /// State Variables ///
    ///////////////////////
    uint256 private constant PRESISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInerestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;
    mapping(address => uint256) private s_userBalance;

    ///////////////////////
    /// Events ///
    ///////////////////////
    event InterestRateSet(uint256 newInterestRate);


    ///////////////////////
    /// constructor ///////
    ///////////////////////

    constructor() ERC20("Rebase token", "RBT") {}


    //////////////////////////
    /// External functions //
    /////////////////////////

    /*
     * @notice sets the new interest rate in the contract  
     * @param _newInterestRate the new interest rate to be set
     * @dev The interest rate can only be decreased.
     */

    function setInterestRate(uint256 _newInterestRate) external {

        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(_newInterestRate, s_interestRate);
        }
        // Set the new Interest Rate
        s_interestRate = _newInterestRate;

        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice this mints the amount of token the user deposits to the vault
     * @param _to the user address
     * @param _amount the amount to be minted
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccrudeInterest(_to);
        s_userInerestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }


    //////////////////////////
    /// Public functions ////
    /////////////////////////

    /**
     * @notice returns the pricipal balance of the user
     * @param _user the address of the user
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principal balance (the number of token that has been currently minted to the user)
        // Multiply the pricipal balance by the interest rate
        return (super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceTheLastUpdate(_user))/PRESISION_FACTOR;
    }


    //////////////////////////
    /// Internal functions //
    /////////////////////////

    /**
     * @notice mints the Accrude interest that the user has sice the last updated ?? i guess ill change this later
     * @param _user the address of the user
     */
    function _mintAccrudeInterest(address _user) internal {
        // (1) Find their current balance of the rebase token that has been minted to the user i.e pricipal balance
        // (2) calculate their current balance including their interest -> balanceOf
        // calculate the number of tokens that is need to be minted to the user (2) - (1)
        // call _mint function to mint the tokens to the user
        // set the users last updated timestamp
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
    }

    function _calculateUserAccumulatedInterestSinceTheLastUpdate(address _user) internal view returns (uint256 linearInterest) {
        // We need to calculate the total interest that has been accumulated since the last update
        // This is going to be a linear growth over time
        // 1. Calculate the total time that has passed since the last update
        // 2. Calculate the amount of linear growth
        //  pricipal amount + (pricipal amount * user interest rate * time elapsed)
        /*
            exmaple: 
            -> user deposits 10 tokens
            -> user interest rate is 0.5 token are per second
            -> time elapsed is 2 senconds
            -> 10 + (10 * 0.5 * 2)
        */ 
       uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
       linearInterest = PRESISION_FACTOR + (s_userInerestRate[_user] * timeElapsed);
    }


    //////////////////////////
    // view & pure functions//
    //////////////////////////
    
    /**
     * @notice retuns the current interest rate that the user has
     * @param _user the address of the user
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInerestRate[_user];
    }
}