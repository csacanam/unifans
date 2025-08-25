// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EventToken
 * @dev ERC20 token representing a specific live event with continuous vesting
 * @dev Each event gets its own token with unique name, symbol, and event details
 * @dev Token distribution: 40% to organizer (with vesting), 60% to initial liquidity pool
 * @dev Organizer tokens are locked until event date with continuous vesting per second
 */
contract EventToken is ERC20, Ownable {
    // Event metadata
    string public eventName; // Name of the live event (e.g., "Concert XYZ")
    uint256 public eventDate; // Timestamp of when the event will take place
    address public immutable organizer; // Address of the event organizer

    // Vesting mechanism
    uint256 public immutable vestingStartTime; // When vesting starts (deployment time)
    uint256 public immutable tokensPerSecond; // Tokens unlocked per second
    uint256 public organizerBalance; // Current balance of organizer (for tracking)

    // Hook integration for one-sided liquidity
    address public eventHook; // Address of the EventCoinHook contract

    // Events
    event OrganizerTransfer(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 remainingBalance
    );
    event HookSet(address indexed hook, uint256 tokensTransferred);

    // Errors
    error ExceedsTransferableAmount(uint256 requested, uint256 transferable);
    error OnlyOrganizer();
    error InvalidEventDate();
    error InvalidOrganizer();
    error InvalidHook();

    /**
     * @dev Constructor to create a new event token
     * @param _eventName Name of the live event (e.g., "Concert XYZ")
     * @param _symbol Token symbol (e.g., "CONCERT", "FESTIVAL", "SHOW")
     * @param _eventDate Timestamp of the event date (must be in the future)
     * @param _organizer Address of the event organizer (must be non-zero)
     */
    constructor(
        string memory _eventName,
        string memory _symbol,
        uint256 _eventDate,
        address _organizer
    ) ERC20(_eventName, _symbol) Ownable(msg.sender) {
        // Validate parameters
        require(
            _eventDate > block.timestamp,
            "Event date must be in the future"
        );
        require(_organizer != address(0), "Invalid organizer address");

        // Store event metadata
        eventName = _eventName;
        eventDate = _eventDate;
        organizer = _organizer;
        vestingStartTime = block.timestamp;

        // Calculate total supply (1 billion tokens with 18 decimals)
        uint256 totalSupply = 1_000_000_000 * 10 ** decimals();

        // Mint 40% to organizer (400M tokens) - these will be locked with vesting
        uint256 organizerAmount = (totalSupply * 40) / 100;
        _mint(_organizer, organizerAmount);
        organizerBalance = organizerAmount;

        // Mint 60% to contract (600M tokens) - for initial liquidity pool
        uint256 contractAmount = totalSupply - organizerAmount;
        _mint(address(this), contractAmount);

        // Calculate tokens per second for continuous vesting
        uint256 vestingDuration = eventDate - vestingStartTime;
        tokensPerSecond = organizerAmount / vestingDuration;
    }

    /**
     * @dev Override transfer function to enforce vesting for organizer
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return bool Success status
     */
    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (msg.sender == organizer) {
            uint256 transferable = organizerTransferableAmount();
            if (amount > transferable) {
                revert ExceedsTransferableAmount(amount, transferable);
            }
            organizerBalance -= amount;
            emit OrganizerTransfer(msg.sender, to, amount, organizerBalance);
        }

        return super.transfer(to, amount);
    }

    /**
     * @dev Override transferFrom function to enforce vesting for organizer
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return bool Success status
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (from == organizer) {
            uint256 transferable = organizerTransferableAmount();
            if (amount > transferable) {
                revert ExceedsTransferableAmount(amount, transferable);
            }
            organizerBalance -= amount;
            emit OrganizerTransfer(from, to, amount, organizerBalance);
        }

        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Override approve function to prevent organizer from approving more than transferable
     * @param spender Address to approve
     * @param amount Amount to approve
     * @return bool Success status
     */
    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        if (msg.sender == organizer) {
            uint256 transferable = organizerTransferableAmount();
            if (amount > transferable) {
                revert ExceedsTransferableAmount(amount, transferable);
            }
        }

        return super.approve(spender, amount);
    }

    /**
     * @dev Calculate how many tokens the organizer can currently transfer
     * @return uint256 Number of transferable tokens
     */
    function organizerTransferableAmount() public view returns (uint256) {
        if (block.timestamp < vestingStartTime) {
            return 0; // Before vesting starts: 0 tokens
        }

        if (block.timestamp >= eventDate) {
            return organizerBalance; // After event: all remaining tokens
        }

        // During vesting: continuous calculation per second
        uint256 timeElapsed = block.timestamp - vestingStartTime;
        uint256 totalUnlocked = tokensPerSecond * timeElapsed;

        // Cap at current balance
        return
            totalUnlocked > organizerBalance ? organizerBalance : totalUnlocked;
    }

    /**
     * @dev Get vesting information for the organizer
     * @return startTime When vesting started
     * @return endTime When vesting ends (event date)
     * @return totalAmount Total tokens for vesting
     * @return transferable Current transferable amount
     * @return remaining Remaining locked tokens
     */
    function getVestingInfo()
        external
        view
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256 totalAmount,
            uint256 transferable,
            uint256 remaining
        )
    {
        startTime = vestingStartTime;
        endTime = eventDate;
        totalAmount = (1_000_000_000 * 10 ** decimals() * 40) / 100; // 40% of total supply
        transferable = organizerTransferableAmount();
        remaining = organizerBalance;
    }

    /**
     * @dev Get current vesting progress as percentage (0-100)
     * @return uint256 Vesting progress percentage
     */
    function getVestingProgress() external view returns (uint256) {
        if (block.timestamp < vestingStartTime) {
            return 0;
        }

        if (block.timestamp >= eventDate) {
            return 100;
        }

        uint256 timeElapsed = block.timestamp - vestingStartTime;
        uint256 totalVestingTime = eventDate - vestingStartTime;

        return (timeElapsed * 100) / totalVestingTime;
    }

    /**
     * @dev Set the hook contract address and transfer ALL available tokens for one-sided liquidity
     * @dev Can only be called by the owner (deployer), and only once
     * @param _hook Address of the EventCoinHook contract
     */
    function setHook(address _hook) external onlyOwner {
        require(_hook != address(0), "Invalid hook address");
        require(eventHook == address(0), "Hook already set");

        eventHook = _hook;

        // Transfer ALL available tokens from contract to hook for one-sided liquidity
        uint256 allTokens = balanceOf(address(this));
        _transfer(address(this), _hook, allTokens);

        emit HookSet(_hook, allTokens);
    }

    /**
     * @dev Modifier to restrict access to organizer only
     */
    modifier onlyOrganizer() {
        if (msg.sender != organizer) {
            revert OnlyOrganizer();
        }
        _;
    }
}
