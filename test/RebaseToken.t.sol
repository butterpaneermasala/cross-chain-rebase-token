// SPDX-Lincese-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebasetoken;
    Vault private vault;
    uint256 private constant PRESISION_FACTOR = 1e18;

    address  public Owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(Owner);
        rebasetoken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebasetoken)));
        rebasetoken.grantMintAndBurnRole(address(vault));
        // payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();

    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success, ) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function testDepositLinear(uint256 amount) public {
        vm.assume(amount > 1e5);
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        // 2. check our rebase token balance
        uint256 startBalance = rebasetoken.balanceOf(user);
        console2.log("Start balance:", startBalance);
        assertEq(startBalance, amount);
        // 3. wrap the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebasetoken.balanceOf(user);
        console2.log("Middle balance:", middleBalance);
        assertGt(middleBalance, startBalance);
        // 4. warp the time again by hte same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebasetoken.balanceOf(user);
        console2.log("End balance:", endBalance);
        assertGt(endBalance, middleBalance);
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        // assertEq(endBalance - middleBalance, middleBalance - startBalance);

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. Deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebasetoken.balanceOf(user), amount);
        // 2. redeem
        vault.redeem(type(uint256).max);
        assertEq(rebasetoken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();

    }

    function testRedeemAfterTimePassed(uint256 depositedAmount, uint256 time) public {
        time = bound(time, 1000, type(uint64).max - block.timestamp);
        depositedAmount = bound(depositedAmount, 1e5, type(uint96).max);
        // 1. despoit
        vm.deal(user, depositedAmount);
        vm.prank(user);
        vault.deposit{value: depositedAmount}();

        // 2. time warp
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebasetoken.balanceOf(user);
        // 2(b). add the rewards to the valut
        vm.deal(Owner, balanceAfterSomeTime - depositedAmount);
        vm.prank(Owner);
        addRewardsToVault(balanceAfterSomeTime - depositedAmount);
        // 3. redeem
        vm.prank(user);
        vault.redeem(type(uint256).max);
        // vm.stopPrank();

        uint256 ethBalance = address(user).balance;
        assertEq(balanceAfterSomeTime, ethBalance);
        assertGt(ethBalance, depositedAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount  = bound(amount, 2e5, type(uint128).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        // 1. deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userbalance = rebasetoken.balanceOf(user);
        uint256 user2balance = rebasetoken.balanceOf(user2);
        assertEq(userbalance, amount);
        assertEq(user2balance, 0);


        // Owner reduces the interest rate
        vm.prank(Owner);
        rebasetoken.setInterestRate(4e10);  

        // 2. Transfer
        vm.prank(user);
        rebasetoken.transfer(user2, amountToSend);
        uint256 userbalanceAfterTransfer = rebasetoken.balanceOf(user);
        uint256 user2balanceAfterTranfer = rebasetoken.balanceOf(user2);
        assertEq(userbalanceAfterTransfer, amount - amountToSend);
        assertEq(user2balanceAfterTranfer, amountToSend);

        // 3. check the user interest rate has been inherited to user2
        assertEq(rebasetoken.getUserInterestRate(user), 5e10);
        assertEq(rebasetoken.getUserInterestRate(user), rebasetoken.getUserInterestRate(user2));
    }

    function testCanNotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(bytes4(Ownable.OwnableUnauthorizedAccount.selector));
        rebasetoken.setInterestRate(newInterestRate);
    }

    function testCanNotMintOrBurn(uint256 amount) public {
        vm.prank(user);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebasetoken.mint(user, amount, 0);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebasetoken.burn(user, amount);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebasetoken.pricipalBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebasetoken.pricipalBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebasetoken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebasetoken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max);
        vm.prank(Owner);
        vm.expectPartialRevert(bytes4(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector));
        rebasetoken.setInterestRate(newInterestRate);
        assertEq(rebasetoken.getInterestRate(), initialInterestRate);
    }
    
    function testCorrectAccumulatedInterest(uint256 amount, uint256 time) public {
        amount = bound(amount, 1e5, type(uint96).max);
        time = bound(time, 1e5, type(uint64).max - block.timestamp);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        uint256 balanceAfterDeposit = rebasetoken.balanceOf(user);
        vm.warp(block.timestamp + time);
        uint256 balanceAfterTimeWarp = rebasetoken.balanceOf(user);
        uint256 expectedBalance = (balanceAfterDeposit * (PRESISION_FACTOR + (rebasetoken.getUserInterestRate(user) * time))) / PRESISION_FACTOR;
        assertApproxEqAbs(balanceAfterTimeWarp, expectedBalance, 5);
    }
}