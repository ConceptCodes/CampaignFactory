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
    struct Brand {
        string name;
        string logo;
    }

    uint256 public MAX_CAMPAIGN_APPLICATION_WINDOW = 7 days;
    uint256 public MIN_CAMPAIGN_LIKE_TIME = 1 days;

    using Counters for Counters.Counter;
    Counters.Counter private campaignCounter;

    // --------------------- MAPPINGS --------------------- //
    mapping(address => Brand) public brands;
    mapping(uint256 => address) public campaigns;
    mapping(uint256 => mapping(address => bool)) public likes;

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
     * @param brand The address of the brand that created the campaign.
     * @param name The name of the campaign created.
     */
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed brand,
        string name,
        uint256 timestamp
    );

    /**
     * @dev Event emitted when a user applies for a campaign.
     * @param campaignId The ID of the campaign the user applied for.
     * @param user The address of the user that applied for the campaign.
     * @param timestamp The timestamp of when the user applied for the campaign.
     */
    event CampaignApplicationSubmitted(
        uint256 indexed campaignId,
        address indexed user,
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

    /**
     * @dev Event emitted when a user likes a campaign.
     * @param campaignId The ID of the campaign the user liked.
     * @param user The address of the user that liked the campaign.
     * @param timestamp The timestamp of when the user liked the campaign.
     */
    event Liked(
        uint256 indexed campaignId,
        address indexed user,
        uint256 timestamp
    );

    /**
     * @dev Event emitted when a user withdraws from a campaign.
     * @param campaignId The ID of the campaign the user withdrew from.
     * @param user The address of the user that withdrew from the campaign.
     * @param timestamp The timestamp of when the user withdrew from the campaign.
     */
    event PayoutWithdrawn(
        uint256 indexed campaignId,
        address indexed user,
        uint256 timestamp
    );

    // --------------------- MODIFIERS --------------------- //

    /// @dev Modifier that checks if the caller is a brand.
    modifier onlyBrand() {
        require(brands[msg.sender], "Only brands can call this function");
        _;
    }

    /// @dev Modifier that checks if the caller is a user.
    modifier onlyUser() {
        require(msg.sender != address(0), "Only users can call this function");
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
            campaign.getCampaignDetails().status == Campaign.Status.Active,
            "Campaign not active"
        );
        require(
            campaign.getCampaignDetails().activeTime >= block.timestamp,
            "Campaign has expired"
        );
        require(!campaign.hasMetLikes(), "Campaign has met minimum likes");
        require(
            campaign.getCampaignDetails().user != address(0),
            "No user associated with campaign"
        );
        _;
    }

    /**
     * @dev Modifier that checks if a campaign is inactive.
     * @param _campaignId The ID of the campaign to check.
     */
    modifier userHasNotLiked(uint256 _campaignId) {
        require(
            !likes[_campaignId][msg.sender],
            "User has already liked this campaign"
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

    /**
     * @dev Modifier that checks if a campaign is inactive.
     * @param _campaignId The ID of the campaign to check.
     */
    modifier withinApplicationWindow(uint256 _campaignId) {
        Campaign campaign = Campaign(campaigns[_campaignId]);
        require(
            campaign.getCampaignDetails().applicationTime >= block.timestamp,
            "Campaign application window has expired"
        );
        _;
    }

    /**
     * @dev Modifier that checks if a campaign is inactive.
     * @param _campaignId The ID of the campaign to check.
     */
    modifier withinLikeWindow(uint256 _campaignId) {
        Campaign campaign = Campaign(campaigns[_campaignId]);
        require(
            campaign.getCampaignDetails().likeTime >= block.timestamp,
            "Campaign like window has expired"
        );
        _;
    }

    // --------------------- FUNCTIONS --------------------- //

    /**
     * @dev Allows the contract owner to add a new brand.
     * @param _brandAddress The address of the brand.
     * @param name The name of the brand.
     */
    function addBrand(
        address _brandAddress,
        string memory name
    ) public onlyOwner {
        require(_brandAddress != address(0), "Invalid brand address");
        require(!brands[_brandAddress], "Brand already added");
        brands[_brandAddress] = Brand(_brandAddress, name);
        emit BrandAdded(_brandAddress, name, block.timestamp);
    }

    /**
     * @dev Allows the contract owner to remove a brand from the contract.
     * @param _brandAddress The address of the brand to remove.
     */
    function removeBrand(address _brandAddress) public onlyOwner {
        require(_brandAddress != address(0), "Invalid brand address");
        require(brands[_brandAddress], "Brand not added");
        string memory name = brands[_brandAddress].name;
        delete brands[_brandAddress];
        emit BrandRemoved(_brandAddress, name, block.timestamp);
    }

    /**
     * @dev Allows a brand to create a new campaign.
     * @notice we use onlyBrand modifier to check if the caller is a brand.
     * @param _name The name of the campaign.
     * @param _description The description of the campaign.
     * @param _image The image of the campaign.
     * @param _minLikes The minimum number of likes required for the campaign.
     * @param _applyTime The time in seconds that the campaign will be open for applications.
     * @param _activeTime The time in seconds that the campaign will be active for.
     * @param _brand The address of the brand that created the campaign.
     */
    function createCampaign(
        string memory _name,
        string memory _description,
        string memory _image,
        uint256 _minLikes,
        uint256 _applyTime,
        uint256 _activeTime,
        address _brand
    ) public payable onlyBrand {
        require(msg.value > 0, "Payout must be greater than zero");
        require(_applyTime > 0, "Apply time must be greater than zero");
        require(_activeTime > 0, "Active time must be greater than zero");
        require(_minLikes > 0, "Minimum likes must be greater than zero");
        require(_brand != address(0), "Invalid brand address");

        Campaign newCampaign = new Campaign(
            _name,
            _description,
            _image,
            _minLikes,
            msg.sender,
            msg.value,
            _applyTime,
            _activeTime,
            _brand
        );

        campaigns[newCampaign.getCampaignDetails().campaignId] = address(
            newCampaign
        );

        emit CampaignCreated(
            newCampaign.getCampaignDetails().campaignId,
            msg.sender,
            _name,
            block.timestamp
        );
    }

    /**
     * @dev Allows a user to apply for a campaign.
     * @notice we use onlyUser modifier to check if the caller is a user.
     * @param _campaignId The ID of the campaign to apply for.
     */
    function applyForCampaign(uint256 _campaignId) public onlyUser {
        Campaign campaign = Campaign(campaigns[_campaignId]);
        require(
            campaign.getCampaignDetails().status == Campaign.Status.Active,
            "Campaign is not active"
        );
        require(
            campaign.getCampaignDetails().applicationWindowEnd >=
                block.timestamp,
            "Application window has closed"
        );
        require(
            !campaign.hasUser(msg.sender),
            "You are already associated with this campaign"
        );

        campaign.submitApplication(msg.sender);

        emit CampaignApplicationSubmitted(
            _campaignId,
            msg.sender,
            block.timestamp
        );
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
        require(
            campaign.getCampaignDetails().brand == msg.sender,
            "Only the brand associated with the campaign can assign a user"
        );
        require(
            campaign.getCampaignDetails().user == address(0),
            "Campaign already has a user associated with it"
        );
        require(
            campaign.hasApplication(_user),
            "User has not applied for this campaign"
        );

        campaign.assignUser(_user);

        emit CampaignUserAssigned(_campaignId, _user, block.timestamp);
    }

    /**
     * @dev Allows a user to like a campaign.
     * @notice we use onlyUser modifier to check if the caller is a user.
     * @notice we use campaignExists modifier to check if the campaign exists.
     * @notice we use campaignIsActive modifier to check if the campaign is active.
     * @notice we use userHasNotLiked modifier to check if the user has not liked the campaign.
     * @notice we use campaignHasNotExpired modifier to check if the campaign has not expired.
     * @param _campaignId The ID of the campaign to like.
     */
    function likeCampaign(
        uint256 _campaignId
    )
        public
        onlyUser
        campaignExists(_campaignId)
        campaignIsActive(_campaignId)
        userHasNotLiked(_campaignId)
        campaignHasNotExpired(_campaignId)
    {
        Campaign campaign = campaigns[_campaignId];

        campaign.incrementTotalLikes();
        likes[_campaignId][msg.sender] = true;

        emit Liked(_campaignId, msg.sender, block.timestamp);

        if (
            campaign.getCampaignDetails().totalLikes >=
            campaign.getCampaignDetails().minLikes
        ) {
            campaign.updateCampaignStatus(Campaign.Status.Finished);
        }
    }
}
