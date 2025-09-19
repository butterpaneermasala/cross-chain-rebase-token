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
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author Satya Pradhan
 * @notice This is a cross-chain rebase token that incentivies users to desposit into a vault and get interests in reward.
 * @notice The interest rate in this smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
 * 
 */


contract RebaseToken is ERC20, Ownable, AccessControl {
    ///////////////////////
    /// Errors ///
    ///////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 newInterestRate, uint256 oldInterestRate);
    ///////////////////////
    /// State Variables ///
    ///////////////////////
    uint256 private constant PRESISION_FACTOR = 1e18;
    uint256 private s_interestRate = (5 * PRESISION_FACTOR) / 1e8;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
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

    constructor() ERC20("Rebase token", "RBT") Ownable(msg.sender) {}


    //////////////////////////
    /// External functions //
    /////////////////////////

    /**
     * @notice Get the principal balance of any user, this is the amount of token that is currently minted to the user, not including any intererest that has accrude since the last time the user interacted with the protocol
     * @param _user the address of the user we want to get the principal balance
     */
    function pricipalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    function grantMintAndBurnRole(address _to) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _to);
    }

    /*
     * @notice sets the new interest rate in the contract  
     * @param _newInterestRate the new interest rate to be set
     * @dev The interest rate can only be decreased.
     */

    function setInterestRate(uint256 _newInterestRate) external onlyOwner {

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
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccrudeInterest(_to);
        s_userInerestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice burn function that bunrs the amount of token when a user wants to withdraw token
     * @param _from the user address to burn from
     * @param _amount the amount of tokens to burn
     */

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = super.balanceOf(_from);
        }
        _mintAccrudeInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice returns the global interest rate
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
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

    
    /**
     * @notice transfer token from one user to another
     * @param _recipient the address of the recipient
     * @param _amount the amount of token to transfer
     */
    function transfer(address _recipient, uint256 _amount) public override returns  (bool) {
        _mintAccrudeInterest(msg.sender);
        _mintAccrudeInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = super.balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInerestRate[_recipient] = s_userInerestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }


    /**
     * @notice transfer tokends from one user to another
     * @param _sender the sender address
     * @param _recipient the recipient address
     * @param _amount the amount of token being sent
     * @return returns True if transer was successfull
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccrudeInterest(_sender);
        _mintAccrudeInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInerestRate[_recipient] = s_userInerestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
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
        uint256 previousPricipalBalance = super.balanceOf(_user);
        // (2) calculate their current balance including their interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens that is need to be minted to the user (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPricipalBalance;
        // set the users last updated timestamp
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
        // call _mint function to mint the tokens to the user
        _mint(_user, balanceIncrease);
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