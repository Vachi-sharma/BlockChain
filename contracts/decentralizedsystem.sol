// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Crowdfunding Platform
 * @dev A smart contract for creating and managing crowdfunding campaigns
 * @author Your Name
 */
contract Project {
    // Struct to represent a crowdfunding campaign
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool goalReached;
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    // State variables
    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public constant MINIMUM_CONTRIBUTION = 0.01 ether;
    
    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    
    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    // Modifiers
    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }
    
    modifier onlyCreator(uint256 _campaignId) {
        require(
            campaigns[_campaignId].creator == msg.sender,
            "Only campaign creator can call this function"
        );
        _;
    }
    
    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].isActive, "Campaign is not active");
        require(
            block.timestamp < campaigns[_campaignId].deadline,
            "Campaign deadline has passed"
        );
        _;
    }

    /**
     * @dev Core Function 1: Create a new crowdfunding campaign
     * @param _title The title of the campaign
     * @param _description The description of the campaign
     * @param _goalAmount The funding goal in wei
     * @param _durationInDays The duration of the campaign in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        
        uint256 campaignId = campaignCounter;
        Campaign storage newCampaign = campaigns[campaignId];
        
        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goalAmount = _goalAmount;
        newCampaign.raisedAmount = 0;
        newCampaign.deadline = block.timestamp + (_durationInDays * 1 days);
        newCampaign.isActive = true;
        newCampaign.goalReached = false;
        
        campaignCounter++;
        
        emit CampaignCreated(
            campaignId,
            msg.sender,
            _title,
            _goalAmount,
            newCampaign.deadline
        );
    }

    /**
     * @dev Core Function 2: Contribute to a campaign
     * @param _campaignId The ID of the campaign to contribute to
     */
    function contribute(uint256 _campaignId) 
        external 
        payable 
        validCampaign(_campaignId) 
        campaignActive(_campaignId) 
    {
        require(msg.value >= MINIMUM_CONTRIBUTION, "Contribution below minimum");
        
        Campaign storage campaign = campaigns[_campaignId];
        
        // If first-time contributor, add to contributors array
        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }
        
        campaign.contributions[msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;
        
        // Check if goal is reached
        if (campaign.raisedAmount >= campaign.goalAmount && !campaign.goalReached) {
            campaign.goalReached = true;
        }
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    /**
     * @dev Core Function 3: Withdraw funds (if goal reached) or refund (if goal not reached and deadline passed)
     * @param _campaignId The ID of the campaign
     */
    function withdrawOrRefund(uint256 _campaignId) 
        external 
        validCampaign(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign still active");
        
        if (campaign.goalReached && msg.sender == campaign.creator) {
            // Creator withdraws funds if goal reached
            require(campaign.raisedAmount > 0, "No funds to withdraw");
            
            uint256 amount = campaign.raisedAmount;
            campaign.raisedAmount = 0;
            campaign.isActive = false;
            
            campaign.creator.transfer(amount);
            emit FundsWithdrawn(_campaignId, msg.sender, amount);
            
        } else if (!campaign.goalReached && campaign.contributions[msg.sender] > 0) {
            // Contributors get refund if goal not reached
            uint256 refundAmount = campaign.contributions[msg.sender];
            campaign.contributions[msg.sender] = 0;
            campaign.raisedAmount -= refundAmount;
            
            payable(msg.sender).transfer(refundAmount);
            emit RefundIssued(_campaignId, msg.sender, refundAmount);
        } else {
            revert("No funds available for withdrawal or refund");
        }
    }

    // View functions
    function getCampaignDetails(uint256 _campaignId) 
        external 
        view 
        validCampaign(_campaignId) 
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            bool goalReached
        ) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.goalReached
        );
    }
    
    function getContribution(uint256 _campaignId, address _contributor) 
        external 
        view 
        validCampaign(_campaignId) 
        returns (uint256) 
    {
        return campaigns[_campaignId].contributions[_contributor];
    }
    
    function getContributorsCount(uint256 _campaignId) 
        external 
        view 
        validCampaign(_campaignId) 
        returns (uint256) 
    {
        return campaigns[_campaignId].contributors.length;
    }
}
