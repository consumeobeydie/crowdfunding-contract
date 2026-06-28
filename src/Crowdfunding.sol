// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title Crowdfunding
/// @notice Goal-based crowdfunding on Arc Testnet.
/// @dev Uses native USDC (18 decimals) as the funding token.
///      If the goal is met before the deadline, the owner can withdraw.
///      If the deadline passes without reaching the goal, contributors can refund.
contract Crowdfunding {
    address public immutable owner;
    uint256 public immutable goal;
    uint256 public immutable deadline;
    string public title;
    string public description;

    uint256 public totalRaised;
    bool public withdrawn;

    mapping(address => uint256) public contributions;
    address[] private contributors;

    event Contributed(address indexed contributor, uint256 amount, uint256 totalRaised);
    event Withdrawn(address indexed owner, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);

    error DeadlinePassed();
    error DeadlineNotPassed();
    error GoalNotMet();
    error GoalAlreadyMet();
    error AlreadyWithdrawn();
    error NothingToRefund();
    error ZeroContribution();
    error NotOwner();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier beforeDeadline() {
        if (block.timestamp >= deadline) revert DeadlinePassed();
        _;
    }

    modifier afterDeadline() {
        if (block.timestamp < deadline) revert DeadlineNotPassed();
        _;
    }

    constructor(string memory _title, string memory _description, uint256 _goal, uint256 _durationSeconds) {
        require(_goal > 0, "Goal must be > 0");
        require(_durationSeconds > 0, "Duration must be > 0");
        owner = msg.sender;
        title = _title;
        description = _description;
        goal = _goal;
        deadline = block.timestamp + _durationSeconds;
    }

    /// @notice Contribute native USDC to the campaign.
    function contribute() external payable beforeDeadline {
        if (msg.value == 0) revert ZeroContribution();
        if (contributions[msg.sender] == 0) {
            contributors.push(msg.sender);
        }
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        emit Contributed(msg.sender, msg.value, totalRaised);
    }

    /// @notice Owner withdraws funds when goal is met (before or after deadline).
    function withdraw() external onlyOwner {
        if (totalRaised < goal) revert GoalNotMet();
        if (withdrawn) revert AlreadyWithdrawn();
        withdrawn = true;
        uint256 amount = totalRaised;
        (bool ok,) = owner.call{value: amount}("");
        require(ok, "Transfer failed");
        emit Withdrawn(owner, amount);
    }

    /// @notice Contributors reclaim funds if goal not met after deadline.
    function refund() external afterDeadline {
        if (totalRaised >= goal) revert GoalAlreadyMet();
        uint256 amount = contributions[msg.sender];
        if (amount == 0) revert NothingToRefund();
        contributions[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "Refund failed");
        emit Refunded(msg.sender, amount);
    }

    /// @notice Returns campaign status summary.
    function getStatus()
        external
        view
        returns (
            uint256 raised,
            uint256 goalAmount,
            uint256 deadlineTimestamp,
            bool goalMet,
            bool campaignActive,
            bool fundsWithdrawn
        )
    {
        return (totalRaised, goal, deadline, totalRaised >= goal, block.timestamp < deadline, withdrawn);
    }

    /// @notice Returns number of unique contributors.
    function contributorCount() external view returns (uint256) {
        return contributors.length;
    }
}
