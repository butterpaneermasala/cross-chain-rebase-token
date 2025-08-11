// SPDX-Lincese-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebasetoken;
    Vault private vault;

    address  public Owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(Owner);
        rebasetoken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebasetoken)));
        rebasetoken.grantMintAndBurnRole(address(vault));
        payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();

    }

    function testDepositLinear(uint256 amount) public {
        vm.assume(amount > 1e5);
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        // 2. check our rebase token balance
        // 3. wrap the time and check the balance again
        // 4. warp the time again by hte same amount and check the balance again
        vm.stopPrank();
    }
}