// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Campaign {
    enum Status {
        Created,
        Active,
        Finished
    }

    struct CampaignDetails {
        string name;
        string description;
        string image;
        uint256 totalLikes;
        uint256 minLikes;
        Status status;
        uint256 payout;
        address user;
        address brand;
        uint256 applicationWindowEnd;
        uint256 campaignEnd;
        mapping(address => bool) applications;
    }

    CampaignDetails private campaignDetails;

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
        campaignDetails.totalLikes = 0;
        campaignDetails.minLikes = _minLikes;
        campaignDetails.status = Status.Created;
        campaignDetails.payout = msg.value;
        campaignDetails.user = address(0);
        campaignDetails.brand = _brand;
        campaignDetails.applicationWindowEnd = block.timestamp + _applyTime;
        campaignDetails.campaignEnd =
            campaignDetails.applicationWindowEnd +
            _activeTime;
    }

    // ----------------- Getters -----------------

    function getCampaignData()
        public
        view
        returns (string memory, string memory, string memory, address)
    {
        return (
            campaignDetails.name,
            campaignDetails.description,
            campaignDetails.image,
            campaignDetails.brand
        );
    }

    function getCampaignUser() public view returns (address) {
        return campaignDetails.user;
    }

    function getCampaignStats()
        public
        view
        returns (uint256, uint256, Status, uint256)
    {
        return (
            campaignDetails.totalLikes,
            campaignDetails.minLikes,
            campaignDetails.status,
            campaignDetails.payout
        );
    }

    function getMinLikes() public view returns (uint256) {
        return campaignDetails.minLikes;
    }

    function getPayout() public view returns (uint256) {
        return campaignDetails.payout;
    }

    function getCampaignEnd() public view returns (uint256) {
        return campaignDetails.campaignEnd;
    }

    function getApplicationWindowEnd() public view returns (uint256) {
        return campaignDetails.applicationWindowEnd;
    }

    // ----------------- Setters -----------------
    function updateCampaignStatus(Status _status) public {
        campaignDetails.status = _status;
    }

    function updateCampaignUser(address _user) public {
        campaignDetails.user = _user;
    }

    // ----------------- Computed Getters -----------------

    function hasMetLikes() public view returns (bool) {
        return campaignDetails.totalLikes >= campaignDetails.minLikes;
    }

    // ----------------- Logic -----------------
    function submitApplication(address _user) public {
        require(
            campaignDetails.status == Status.Created,
            "Campaign is not accepting applications"
        );
        require(
            block.timestamp <= campaignDetails.applicationWindowEnd,
            "Application window has closed"
        );
        require(
            !campaignDetails.applications[_user],
            "User has already applied"
        );
        campaignDetails.applications[_user] = true;
    }

    function registerLike() public {
        require(
            campaignDetails.status == Status.Active,
            "Campaign is not active"
        );
        require(
            block.timestamp <= campaignDetails.campaignEnd,
            "Campaign has ended"
        );
        campaignDetails.totalLikes++;
    }

    function payout() public {
        require(
            campaignDetails.status == Status.Finished,
            "Campaign is not finished"
        );
        require(campaignDetails.user != address(0), "Campaign has no user");
        require(campaignDetails.payout > 0, "Campaign has no payout");
        payable(campaignDetails.user).transfer(campaignDetails.payout);
    }
}
