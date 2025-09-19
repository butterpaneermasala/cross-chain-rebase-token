// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    // We need to pass token address to the constructor
    // create a deposit function that mints token to the user the equal amount of ETH the user has deposited
    // create a redeem function that burns token from the user and sends the user ETH
    // create a way to add rewards to the vault

    IRebaseToken immutable private i_rebaseToken;

    error Vault__RedeemFailed(address user, uint256 amount);

    event Deposit(address indexed sender, uint256 amount);
    event Redeem(address indexed sender, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {

    }


    /**
     * @notice Allows users to deposit ETH into the valut and receive Rebase token in return
     */
    function deposit() external payable {
        i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        emit Deposit(msg.sender, msg.value);
    }


    /**
     * @notice Allows users to redeem their Rebase token for ETH
     * @param _amount the amount of Rebase token the user wants to redeem
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // 1. We need to first burn the tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);
        // 2. We need to send the user ETH
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed(msg.sender, _amount);
        }

        emit Redeem(msg.sender, _amount);
    }

    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}