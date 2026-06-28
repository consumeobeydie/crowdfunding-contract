// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/Crowdfunding.sol";

contract CrowdfundingTest is Test {
    receive() external payable {}
    Crowdfunding public campaign;
    address public owner = address(this);
    address public alice = address(0xA11CE);
    address public bob   = address(0xB0B);

    uint256 constant GOAL     = 1 ether;
    uint256 constant DURATION = 7 days;

    function setUp() public {
        campaign = new Crowdfunding(
            "Arc Builder Fund",
            "Fund Arc ecosystem builders",
            GOAL,
            DURATION
        );
        vm.deal(alice, 10 ether);
        vm.deal(bob,   10 ether);
    }

    function testInitialState() public view {
        assertEq(campaign.title(), "Arc Builder Fund");
        assertEq(campaign.goal(), GOAL);
        assertEq(campaign.totalRaised(), 0);
        assertEq(campaign.withdrawn(), false);
        assertEq(campaign.contributorCount(), 0);
    }

    function testContribute() public {
        vm.prank(alice);
        campaign.contribute{value: 0.5 ether}();
        assertEq(campaign.totalRaised(), 0.5 ether);
        assertEq(campaign.contributions(alice), 0.5 ether);
        assertEq(campaign.contributorCount(), 1);
    }

    function testMultipleContributors() public {
        vm.prank(alice);
        campaign.contribute{value: 0.5 ether}();
        vm.prank(bob);
        campaign.contribute{value: 0.7 ether}();
        assertEq(campaign.totalRaised(), 1.2 ether);
        assertEq(campaign.contributorCount(), 2);
    }

    function testContributeAfterDeadlineReverts() public {
        vm.warp(block.timestamp + DURATION + 1);
        vm.prank(alice);
        vm.expectRevert(Crowdfunding.DeadlinePassed.selector);
        campaign.contribute{value: 0.5 ether}();
    }

    function testZeroContributionReverts() public {
        vm.prank(alice);
        vm.expectRevert(Crowdfunding.ZeroContribution.selector);
        campaign.contribute{value: 0}();
    }

    function testWithdrawWhenGoalMet() public {
        vm.prank(alice);
        campaign.contribute{value: 1 ether}();
        uint256 balanceBefore = owner.balance;
        campaign.withdraw();
        assertGt(owner.balance, balanceBefore);
        assertEq(campaign.withdrawn(), true);
    }

    function testWithdrawGoalNotMetReverts() public {
        vm.prank(alice);
        campaign.contribute{value: 0.5 ether}();
        vm.expectRevert(Crowdfunding.GoalNotMet.selector);
        campaign.withdraw();
    }

    function testDoubleWithdrawReverts() public {
        vm.prank(alice);
        campaign.contribute{value: 1 ether}();
        campaign.withdraw();
        vm.expectRevert(Crowdfunding.AlreadyWithdrawn.selector);
        campaign.withdraw();
    }

    function testRefundAfterDeadline() public {
        vm.prank(alice);
        campaign.contribute{value: 0.3 ether}();
        vm.warp(block.timestamp + DURATION + 1);
        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        campaign.refund();
        assertEq(alice.balance, balanceBefore + 0.3 ether);
        assertEq(campaign.contributions(alice), 0);
    }

    function testRefundBeforeDeadlineReverts() public {
        vm.prank(alice);
        campaign.contribute{value: 0.3 ether}();
        vm.prank(alice);
        vm.expectRevert(Crowdfunding.DeadlineNotPassed.selector);
        campaign.refund();
    }

    function testRefundWhenGoalMetReverts() public {
        vm.prank(alice);
        campaign.contribute{value: 1 ether}();
        vm.warp(block.timestamp + DURATION + 1);
        vm.prank(alice);
        vm.expectRevert(Crowdfunding.GoalAlreadyMet.selector);
        campaign.refund();
    }

    function testNothingToRefundReverts() public {
        vm.warp(block.timestamp + DURATION + 1);
        vm.prank(alice);
        vm.expectRevert(Crowdfunding.NothingToRefund.selector);
        campaign.refund();
    }

    function testGetStatus() public {
        vm.prank(alice);
        campaign.contribute{value: 0.5 ether}();
        (uint256 raised, uint256 goalAmt,, bool goalMet, bool active,) = campaign.getStatus();
        assertEq(raised, 0.5 ether);
        assertEq(goalAmt, GOAL);
        assertEq(goalMet, false);
        assertEq(active, true);
    }

    function testOnlyOwnerWithdraw() public {
        vm.prank(alice);
        campaign.contribute{value: 1 ether}();
        vm.prank(alice);
        vm.expectRevert(Crowdfunding.NotOwner.selector);
        campaign.withdraw();
    }
}
