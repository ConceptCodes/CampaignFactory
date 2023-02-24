// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Campaign
 * @author conceptcodes.eth
 * @notice This contract is used to represent a campaign.
 * @dev All function calls are currently intended to be made by the dApp only
 */
contract Campaign is Ownable, AccessControl {
    // ----------------- Variables -----------------
    Details private campaignDetails;

    using Counters for Counters.Counter;
    Counters.Counter private totalLikes;
    Counters.Counter private numApplications;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    // ----------------- Events -----------------

    /**
     * @dev Emitted when the status of the campaign is updated
     * @param status the new status of the campaign
     * @param timestamp timestamp of the event
     */
    event StatusUpdated(Status status, uint256 timestamp);

    /**
     * @dev Emitted when a user submits an application to the campaign
     * @param user the user who submitted the application
     * @param timestamp timestamp of the event
     */
    event Liked(address user, uint256 timestamp);

    /**
     * @dev Emitted when a user's application is chosen
     * @param user the user who submitted the application
     * @param numApplications number of applications to the campaign
     * @param timestamp timestamp of the event
     */
    event UserSelected(
        address user,
        uint256 numApplications,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a user submits an application to the campaign
     * @param user the user who submitted the application
     * @param timestamp timestamp of the event
     */
    event Applied(address user, uint256 timestamp);

    /**
     * @dev Emitted when a user withdraws their payout from the campaign
     * @param totalLikes total number of likes the campaign received
     * @param minLikes minimum number of likes required to receive payout
     * @param timestamp timestamp of the event
     */
    event Withdrawal(
        uint256 totalLikes,
        uint256 minLikes,
        uint256 timestamp
    );

    // ----------------- Structs, Enums, Mappings -----------------

    struct Details {
        string name;
        string description;
        string image;
        uint256 minLikes;
        Status status;
        uint256 payout;
        address user;
        address brand;
        uint256 applicationWindowEnd;
        uint256 campaignEnd;
    }

    enum Status {
        Created,
        Active,
        Finished
    }

    mapping(address => bool) public likes;
    mapping(address => bool) private applications;

    // ----------------- Constructor -----------------
    constructor(
        string memory _name,
        string memory _description,
        string memory _image,
        uint256 _minLikes,
        uint256 _applyTime,
        uint256 _activeTime,
        address _brand
    ) payable {
        campaignDetails.name = _name;
        campaignDetails.description = _description;
        campaignDetails.image = _image;
        campaignDetails.minLikes = _minLikes;
        campaignDetails.status = Status.Created;
        campaignDetails.payout = msg.value;
        campaignDetails.user = address(0);
        campaignDetails.brand = _brand;

        campaignDetails.applicationWindowEnd = block.timestamp + _applyTime;
        campaignDetails.campaignEnd =
            campaignDetails.applicationWindowEnd +
            _activeTime;

        emit StatusUpdated(campaignDetails.status, block.timestamp);
    }

    // ----------------- Getters -----------------

    function getDetails()
        public
        view
        returns (string memory, string memory, string memory)
    {
        return (
            campaignDetails.name,
            campaignDetails.description,
            campaignDetails.image
        );
    }

    function getUser() public view returns (address) {
        return campaignDetails.user;
    }

    function getStatus() public view returns (Status) {
        return campaignDetails.status;
    }

    function getTotalLikes() public view returns (uint256) {
        return totalLikes.current();
    }

    function getMinLikes() public view returns (uint256) {
        return campaignDetails.minLikes;
    }

    function getPayoutAmt() public view returns (uint256) {
        return campaignDetails.payout;
    }

    function getCampaignEnd() public view returns (uint256) {
        return campaignDetails.campaignEnd;
    }

    function getApplicationWindowEnd() public view returns (uint256) {
        return campaignDetails.applicationWindowEnd;
    }

    function hasMetLikeGoal() public view returns (bool) {
        return totalLikes.current() >= campaignDetails.minLikes;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getBrand() public view returns (address) {
        return campaignDetails.brand;
    }

    // ----------------- Setters -----------------
    function updateStatus(Status _status) public onlyRole(ADMIN_ROLE) {
        campaignDetails.status = _status;
    }

    function assign(address _user) public onlyRole(ADMIN_ROLE) {
        campaignDetails.user = _user;
        _grantRole(USER_ROLE, _user);
    }

    // ----------------- Logic -----------------
    function applyForCampaign() public {
        require(
            campaignDetails.status == Status.Created,
            "Campaign is not accepting applications"
        );
        require(
            block.timestamp <= campaignDetails.applicationWindowEnd,
            "Application window has closed"
        );
        require(
            !applications[msg.sender],
            "You have already applied to this campaign"
        );
        applications[msg.sender] = true;
        numApplications.increment();
        emit Applied(msg.sender, block.timestamp);
    }

    function like() public {
        require(
            campaignDetails.status == Status.Active,
            "Campaign is not active"
        );
        require(
            block.timestamp <= campaignDetails.campaignEnd,
            "Campaign has ended"
        );
        require(!likes[msg.sender], "You have already liked this campaign");
        emit Liked(msg.sender, block.timestamp);
        totalLikes.increment();
    }

    // TODO: Add reentrancy guard
    function payout() public onlyOwner onlyRole(USER_ROLE) {
        require(
            campaignDetails.status == Status.Finished,
            "Campaign is not finished"
        );
        require(campaignDetails.user != address(0), "Campaign has no user");
        require(campaignDetails.payout > 0, "Campaign has no payout");
        payable(campaignDetails.user).transfer(campaignDetails.payout);

        emit Withdrawal(
            totalLikes.current(),
            campaignDetails.minLikes,
            block.timestamp
        );
    }
}
