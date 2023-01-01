// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Campaign Factory
 * @author conceptcodes.eth
 * @notice This contract is used to manage social media campaigns
 */
contract CampaignFactory is Ownable {
    error ValidationError();

    error PreConditionError(uint256 id);

    error CampaignDoesNotExist(uint256 id);

    error UserAlreadyApplied(uint256 id, address user);

    using Counters for Counters.Counter;

    Counters.Counter private _campaignIds;

    enum Status {
        Created,
        Active,
        Finished
    }

    struct Campaign {
        string name;
        string description;
        string image;
        uint256 totalLikes;
        uint256 minLikes;
        Status status;
        uint256 payout;
        address user;
        uint256 activeTime;
    }

    struct Brand {
        string name;
        string description;
        string image;
    }

    /**
     * @notice A mapping of address to brands
     * @dev This mapping is used to keep track of all brands
     */
    mapping(address => Brand) brands;

    /**
     * @notice A mapping of campaign ids to campaigns
     * @dev This mapping is used to keep track of all campaigns
     *     created by brands
     */
    mapping(uint256 => Campaign) campaigns;

    /**
     * @notice A mapping of campaign ids to user addresses
     * @dev This mapping is used to keep track of which users liked a campaign
     */
    mapping(uint256 => mapping(address => bool)) likes;

    /**
     * @notice A mapping of campaign ids to user addresses
     * @dev This mapping is used to keep track of which users
     *      applied to participate in a campaign
     */
    mapping(uint256 => mapping(address => bool)) public applications;

    /**
     * @notice Emitted when a new campaign is created
     * @param id The id of the campaign
     * @param name The name of the campaign
     * @param minLikes The minimum number of likes to finish the campaign
     * @param endDate The end date of the campaign
     * @param timestamp The timestamp of the event
     */
    event Created(
        uint256 id,
        string name,
        uint256 minLikes,
        uint256 endDate,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a user applies to a campaign
     * @param id The id of the campaign
     * @param user The address of the user
     * @param timestamp The timestamp of the event
     */
    event Applied(uint256 id, address indexed user, uint256 timestamp);

    /**
     * @notice Emitted when a user gets assigned to a campaign
     * @param id The id of the campaign
     * @param user The address of the user
     * @param timestamp The timestamp of the event
     */
    event Assigned(uint256 id, address indexed user, uint256 timestamp);

    /**
     * @notice Emitted when a user likes a campaign
     * @param id The id of the campaign
     * @param user The address of the user
     * @param timestamp The timestamp of the event
     */
    event Liked(uint256 id, address indexed user, uint256 timestamp);

    /**
     * @notice Emitted when a campaign is finished
     * @param id The id of the campaign
     * @param user The address of the user
     * @param payout The payout of the campaign
     * @param timestamp The timestamp of the event
     */
    event Finished(
        uint256 id,
        address indexed user,
        uint256 payout,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a new brand is added
     * @param brand The address of the brand
     * @param name The name of the brand
     * @param description The description of the brand
     * @param image The brand image
     */
    event BrandAdded(address brand, string name, string description, string image);

    /**
     * @notice Emitted when a brand is removed
     * @param id The id of the brand
     */
    event BrandRemoved(uint256 id);

    /**
     * @notice Modifier to check if a campaign exists
     * @param _id The id of the campaign
     */
    modifier canApply(uint256 _id) {
        if (_id >= _campaignIds.current()) {
            revert CampaignDoesNotExist(_id);
        }

        if (campaigns[_id].status != Status.Created) {
            revert PreConditionError(_id);
        }

        if (campaigns[_id].activeTime < block.timestamp) {
            revert PreConditionError(_id);
        }

        _;
    }

    constructor() {}

    /**
     * @notice Create a new campaign
     * @param _name The name of the campaign
     * @param _description The description of the campaign
     * @param _image The campaign image
     * @param _minLikes The minimum number of likes to finish the campaign
     * @param _activeTime The time the campaign will be active
     * @dev we use the onlyOwner modifier to ensure that only the contract owner can create a campaign
     */
    function create(
        string memory _name,
        string memory _description,
        string memory _image,
        uint256 _minLikes,
        uint256 _activeTime
    ) public payable {
        if (_activeTime <= 0) revert ValidationError();
        if (_minLikes <= 0) revert ValidationError();
        if (bytes(_name).length <= 0) revert ValidationError();
        if (msg.value <= 0) revert ValidationError();
        if (brands[msg.sender].name == "") revert ValidationError();
        
        uint256 newCampaignIdea = _campaignIds.current();

        campaigns[newCampaignIdea] = Campaign({
            name: _name,
            description: _description,
            image: _image,
            totalLikes: 0,
            minLikes: _minLikes,
            status: Status.Created,
            payout: msg.value,
            user: address(0),
            activeTime: block.timestamp + _activeTime
        });

        _campaignIds.increment();

        emit Created(
            newCampaignIdea,
            _name,
            _minLikes,
            block.timestamp + _activeTime,
            block.timestamp
        );
    }

    /**
     * @notice assign a user to a campaign
     * @param _id The id of the campaign
     */
    function submitApplication(uint256 _id) public canApply(_id) {
        if (campaigns[_id].user != address(0)) {
            revert PreConditionError(_id);
        }

        if (applications[_id][msg.sender])
            revert UserAlreadyApplied(_id, msg.sender);

        applications[_id][msg.sender] = true;

        emit Applied(_id, msg.sender, block.timestamp);
    }

    /**
     * @notice accept a user to a campaign
     * @param _id The id of the campaign
     * @param _user The address of the user
     */
    function reviewApplications(
        uint256 _id,
        address _user
    ) public onlyOwner canApply(_id) {
        if (!applications[_id][_user]) revert UserAlreadyApplied(_id, _user);

        campaigns[_id].user = _user;
        campaigns[_id].status = Status.Active;

        delete applications[_id][_user];

        emit Assigned(_id, _user, block.timestamp);
    }

    /**
     * @notice like a campaign
     * @param _id The id of the campaign
     * @dev If the campaign is active, the user can like the campaign once
     */
    function like(uint256 _id) public {
        if (campaigns[_id].status != Status.Active) {
            revert PreConditionError(_id);
        }

        if (campaigns[_id].activeTime < block.timestamp) {
            revert PreConditionError(_id);
        }

        if (likes[_id][msg.sender]) {
            revert PreConditionError(_id);
        }

        likes[_id][msg.sender] = true;
        campaigns[_id].totalLikes++;

        emit Liked(_id, msg.sender, block.timestamp);
    }

    /**
     * @notice get the number of campaigns
     * @return The number of campaigns
     */
    function getCampaignCount() public view returns (uint256) {
        return _campaignIds.current();
    }

    /**
     * @notice get the campaign details
     * @param _id The id of the campaign
     * @return The campaign details
     */
    function getCampaign(uint256 _id) public view returns (Campaign memory) {
        return campaigns[_id];
    }

    /**
     * @notice withdraw the payout of a campaign
     * @dev If the campaign is finished, the user can withdraw their payout amount
     * @param _id The id of the campaign
     */
    function withdraw(uint256 _id) public {
        if (campaigns[_id].user != msg.sender) {
            revert PreConditionError(_id);
        }

        if (campaigns[_id].totalLikes >= campaigns[_id].minLikes) {
            campaigns[_id].status = Status.Finished;
            emit Finished(
                _id,
                msg.sender,
                campaigns[_id].payout,
                block.timestamp
            );
        }

        payable(msg.sender).transfer(campaigns[_id].payout);
    }

    /**
     * @notice add a new brand
     * @param _name The name of the brand
     * @param _description The description of the brand
     * @param _image The brand image
     */
    function addBrand(
        string memory _name,
        string memory _description,
        string memory _image,
        address _brandAddress
    ) public onlyOwner {
        brands[_brandAddress] = Brand({
            name: _name,
            description: _description,
            image: _image
        });

        emit BrandAdded(newBrandId, _name, _description, _image);
    }

    /**
     * @notice remove a brand
     * @param _brandAddress The address of the brand
     */
    function removeBrand(address _brandAddress) public onlyOwner {
        delete brands[_brandAddress];
        emit BrandRemoved(newBrandId);
    }
}
