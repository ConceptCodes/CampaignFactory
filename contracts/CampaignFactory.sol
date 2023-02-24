// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Campaign.sol";

/**
 * @title CampaignFactory
 * @dev Contract that allows brands to create campaigns and users to apply for them.
 * @author conceptcodes.eth
 * @notice You can use this contract for only the most basic simulation.
 * @dev All function calls are currently intended to be made by the dApp only
 */
contract CampaignFactory is Ownable {
    // --------------------- STRUCTS & VARIABLES --------------------- //

    uint256 public MAX_CAMPAIGN_APPLICATION_WINDOW = 7 days;
    uint256 public MIN_CAMPAIGN_ACTIVE_TIME = 1 days;

    Counters.Counter private campaignIds;
    using Counters for Counters.Counter;

    struct Brand {
        string name;
        string logo;
        uint256[] campaigns;
        bool onboarded;
    }

    // --------------------- MAPPINGS --------------------- //
    mapping(address => Brand) public brands;
    mapping(uint256 => address) public campaigns;

    // --------------------- EVENTS --------------------- //

    /**
     * @dev Event emitted when a brand is added to the contract.
     * @param brand The address of the brand added.
     * @param name The name of the brand added.
     * @param timestamp The timestamp of when the brand was added.
     */
    event BrandAdded(address indexed brand, string name, uint256 timestamp);

    /**
     * @dev Event emitted when a brand is removed from the contract.
     * @param brand The address of the brand removed.
     * @param name The name of the brand removed.
     * @param timestamp The timestamp of when the brand was removed.
     */
    event BrandRemoved(address indexed brand, string name, uint256 timestamp);

    /**
     * @dev Event emitted when a campaign is created.
     * @param campaignId The ID of the campaign created.
     * @param instance The address of the campaign instance.
     * @param brand The address of the brand that created the campaign.
     * @param name The name of the campaign created.
     */
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed instance,
        address indexed brand,
        string name,
        uint256 timestamp
    );

    /**
     * @dev Event emitted when a user is assigned to a campaign.
     * @param campaignId The ID of the campaign the user was assigned to.
     * @param user The address of the user that was assigned to the campaign.
     * @param timestamp The timestamp of when the user was assigned to the campaign.
     */
    event CampaignUserAssigned(
        uint256 indexed campaignId,
        address indexed user,
        uint256 timestamp
    );

    // --------------------- MODIFIERS --------------------- //

    /// @dev Modifier that checks if the caller is a brand.
    modifier onlyBrand() {
        require(
            brands[msg.sender].onboarded,
            "Only brands can call this function"
        );
        _;
    }

    /**
     * @dev Modifier that checks if a campaign exists.
     * @param _campaignId The ID of the campaign to check.
     */
    modifier campaignExists(uint256 _campaignId) {
        require(
            campaigns[_campaignId] != address(0),
            "Campaign does not exist"
        );
        _;
    }

    /**
     * @dev Modifier that checks if a campaign is active and still accepting likes and user assignments.
     * @param _campaignId The ID of the campaign to check.
     */
    modifier campaignIsActive(uint256 _campaignId) {
        Campaign campaign = Campaign(campaigns[_campaignId]);
        require(
            campaign.getCampaignStatus() == Campaign.Status.Active,
            "Campaign not active"
        );
        require(
            campaign.getCampaignEnd() >= block.timestamp,
            "Campaign has expired"
        );
        require(!campaign.hasMetLikeGoal(), "Campaign has met minimum likes");
        require(
            campaign.getCampaignUser() != address(0),
            "No user associated with campaign"
        );
        _;
    }

    /**
     * @dev Modifier that checks if a campaign is inactive.
     * @param _campaignId The ID of the campaign to check.
     */
    modifier campaignHasNotExpired(uint256 _campaignId) {
        Campaign campaign = Campaign(campaigns[_campaignId]);
        require(
            campaign.getCampaignDetails().activeTime >= block.timestamp,
            "Campaign has expired"
        );
        _;
    }

    // --------------------- FUNCTIONS --------------------- //

    /**
     * @dev Allows the contract owner to add a brand to the contract.
     * @param name The name of the brand.
     * @param logo The logo of the brand.
     * @param brandAddress The address of the brand.
     */
    function addBrand(
        string memory name,
        string memory logo,
        address brandAddress
    ) public onlyOwner {
        require(brandAddress != address(0), "Invalid brand address");
        require(!brands[brandAddress].onboarded, "Brand already added");
        brands[brandAddress] = Brand(name, logo, new uint256[](0), true);
        emit BrandAdded(brandAddress, name, block.timestamp);
    }

    /**
     * @dev Allows the contract owner to remove a brand from the contract.
     * @param brandAddress The address of the brand to remove.
     */
    function removeBrand(address brandAddress) public onlyOwner {
        require(brandAddress != address(0), "Invalid brand address");
        require(brands[brandAddress].onboarded, "Brand not added");
        string memory name = brands[brandAddress].name;
        delete brands[brandAddress];
        emit BrandRemoved(brandAddress, name, block.timestamp);
    }

    /**
     * @dev Allows a brand to create a new campaign.
     * @notice we use onlyBrand modifier to check if the caller is a brand.
     * @param _name The name of the campaign.
     * @param _description The description of the campaign.
     * @param _image The image of the campaign.
     * @param _brand The address of the brand that created the campaign.
     * @param _minLikes The minimum number of likes required for the campaign.
     * @param _applyTime The time in seconds that the campaign will be open for applications.
     * @param _activeTime The time in seconds that the campaign will be active for.
     */
    function createCampaign(
        string memory _name,
        string memory _description,
        string memory _image,
        address _brand,
        uint256 _minLikes,
        uint256 _applyTime,
        uint256 _activeTime
    ) public payable onlyBrand {
        require(msg.value > 0, "Payout must be greater than zero");

        require(_applyTime > 0, "Apply time must be greater than zero");
        require(
            _applyTime < MAX_CAMPAIGN_APPLICATION_WINDOW,
            "Application window is too large"
        );

        require(
            _activeTime > MIN_CAMPAIGN_ACTIVE_TIME,
            "Active time must be greater than zero"
        );

        require(_minLikes > 0, "Minimum likes must be greater than zero");

        require(_brand != address(0), "Invalid brand address");

        uint256 campaignId = campaignIds.current();
        campaignIds.increment();

        Campaign newCampaign = new Campaign(
            _name,
            _description,
            _image,
            _minLikes,
            msg.sender,
            0,
            _applyTime,
            _activeTime,
            _brand,
            campaignId
        );

        address payable campaignAddress = payable(address(newCampaign));
        campaignAddress.transfer(msg.value);

        campaigns[campaignId] = address(newCampaign);

        emit CampaignCreated(
            campaignId,
            address(newCampaign),
            msg.sender,
            _name,
            block.timestamp
        );

        brands[_brand].campaigns.push(campaignId);

        newCampaign.transferOwnership(address(this));
        newCampaign._grantRole(AccessControl.DEFAULT_ADMIN_ROLE, address(this));
        newCampaign.
    }

    /**
     * @dev Allows a brand to assign a user to a campaign.
     * @notice we use onlyBrand modifier to check if the caller is a brand.
     * @notice we use campaignExists modifier to check if the campaign exists.
     * @notice we use campaignIsActive modifier to check if the campaign is active.
     * @param _campaignId The ID of the campaign to assign a user to.
     * @param _user The address of the user to assign to the campaign.
     */
    function assignUserToCampaign(
        uint256 _campaignId,
        address _user
    )
        public
        onlyBrand
        campaignExists(_campaignId)
        campaignIsActive(_campaignId)
    {
        Campaign campaign = Campaign(campaigns[_campaignId]);
        campaign._assign(_user);
        emit CampaignUserAssigned(_campaignId, _user, block.timestamp);
    }

    function allowBrandToSelectUser(address contractAddress, uint256 timestamp) public onlyOwner {
        Campaign campaign = Campaign(contractAddress);
        campaign.allowBrand(timestamp);
    }

}
