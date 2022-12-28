// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Campaign Factory
 * @author conceptcodes.eth
 * @notice This contract is used to manage social media campaigns
 */
contract CampaignFactory is Ownable {
    error ValidationError();

    /**
     * @notice Thrown when a campaign is not active
     * @param id The id of the campaign
     */
    error NotActiveError(uint256 id);

    /**
     * @notice Thrown when a precondition is not met
     * @param id The id of the campaign
     */
    error PreConditionError(uint256 id);

    enum Status {
        Created,
        Active,
        Finished
    }

    /**
     * @notice A mapping of campaign ids to user addresses
     * @dev This mapping is used to keep track of which users liked a campaign
     */
    mapping(uint256 => mapping(address => bool)) likes;

    struct Campaign {
        string name;
        string description;
        string image;
        uint256 totalLikes;
        uint256 minLikes;
        Status status;
        uint256 payout;
        address payable user;
        uint256 activeTime;
    }

    Campaign[] campaigns;

    /**
     * @notice Emitted when a new campaign is created
     * @param id The id of the campaign
     * @param name The name of the campaign
     * @param minLikes The minimum number of likes to finish the campaign
     * @param endDate The end date of the campaign
     */
    event Created(uint256 id, string name, uint256 minLikes, uint256 endDate);

    /**
     * @notice Emitted when a user gets assigned to a campaign
     * @param id The id of the campaign
     * @param user The address of the user
     */
    event Assigned(uint256 id, address indexed user);

    /**
     * @notice Emitted when a user likes a campaign
     * @param id The id of the campaign
     * @param user The address of the user
     */
    event Liked(uint256 id, address indexed user);

    /**
     * @notice Emitted when a campaign is finished
     * @param id The id of the campaign
     * @param user The address of the user
     * @param payout The payout of the campaign
     */
    event Finished(uint256 id, address indexed user, uint256 payout);

    constructor() {}

    /**
     * @notice Create a new campaign
     * @param _name The name of the campaign
     * @param _description The description of the campaign
     * @param _image The image of the campaign
     * @param _minLikes The minimum number of likes to finish the campaign
     * @param _activeTime The time the campaign will be active
     * @dev The campaign is intially assigned to the contract owner,
     *      but users can link an inactive campaign to their address
     * @dev we use the onlyOwner modifier to ensure that only the contract owner can create a campaign
     */
    function create(
        string memory _name,
        string memory _description,
        string memory _image,
        uint256 _minLikes,
        uint256 _activeTime
    ) public payable onlyOwner {
        if (_activeTime <= 0) revert ValidationError();
        if (_minLikes <= 0) revert ValidationError();
        if (bytes(_name).length <= 0) revert ValidationError();
        if (msg.value <= 0) revert ValidationError();

        Campaign storage c = campaigns.push();

        c.name = _name;
        c.description = _description;
        c.image = _image;
        c.minLikes = _minLikes;
        c.status = Status.Created;
        c.payout = msg.value;
        c.activeTime = block.timestamp + _activeTime;

        payable(address(this)).transfer(msg.value);

        emit Created(
            campaigns.length - 1,
            _name,
            _minLikes,
            block.timestamp + _activeTime
        );
    }

    /**
     * @notice assign a user to a campaign
     * @param _id The id of the campaign
     * @dev If the campaign is not active & time is still availble,
     *      it will be linked to the senders address
     */
    function assign(uint256 _id) public {
        if (
            campaigns[_id].status != Status.Created ||
            campaigns[_id].status != Status.Finished
        ) {
            revert PreConditionError(_id);
        }

        if (campaigns[_id].activeTime < block.timestamp) {
            revert PreConditionError(_id);
        }

        campaigns[_id].user = payable(msg.sender);
        campaigns[_id].status = Status.Active;

        emit Assigned(_id, msg.sender);
    }

    /**
     * @notice like a campaign
     * @param _id The id of the campaign
     * @dev If the campaign is active, the user can like it
     */
    function like(uint256 _id) public {
        if (campaigns[_id].status != Status.Active) {
            revert NotActiveError(_id);
        }
        if (campaigns[_id].activeTime < block.timestamp) {
            revert NotActiveError(_id);
        }
        if (likes[_id][msg.sender]) {
            revert PreConditionError(_id);
        }

        likes[_id][msg.sender] = true;
        campaigns[_id].totalLikes++;

        emit Liked(_id, msg.sender);
    }

    /**
     * @notice get the number of campaigns
     * @return The number of campaigns
     */
    function getCampaignCount() public view returns (uint256) {
        return campaigns.length;
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
            emit Finished(_id, msg.sender, campaigns[_id].payout);
        }

        payable(msg.sender).transfer(campaigns[_id].payout);
    }
}
