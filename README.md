# Campaign Factory Smart Contract

The Campaign Factory smart contract is designed to streamline the management of social media campaigns by automating the process of selecting and rewarding content creators for their social media engagement. 
Brands can use the contract to create campaigns, specify the required number of likes, and set the reward for completing the campaign. Users can then apply to participate in a campaign, and the contract will select one user to complete the like goal. 
The use of a smart contract on the Ethereum blockchain ensures transparency and security for all parties involved in the campaign.

[Testnet Deployment](https://goerli.etherscan.io/address/0x8e0b7e6062272b5e023ecd2be471e95d5f7b6a8a#code) |
[Mainnet Deployment](https://etherscan.io/address/0x8e0b7e6062272b5e023ecd2be471e95d5f7b6a8a#code)


## Features
- Brands can create new campaigns and track their engagement.
- Users can apply to participate in a campaign.
- The owner of the contract can assign a user to a campaign 
  - if they have not chosen a random user is selected.
- Users can engage with a campaign by giving a like.
- When a campaign reaches its performance goal.
  - The user who participated in the campaign receives a payout.


## Roadmap
- [ ] Add a max application limit to campaigns, and 
- [ ] Time lock a transaction to pick a random user, once application limit is finished.
- [ ] Ability for users to withdraw their application.
- [ ] Add a cap to the amount of open applications a user can have.

## Dependencies
[OpenZeppelin Ownable](https://docs.openzeppelin.com/contracts/4.x/api/access#Ownable) 
To manage the ownership of the Campaign Factory contract.

[OpenZeppelin Counters](https://docs.openzeppelin.com/contracts/4.x/api/utils#Counters) 
Generate unique IDs for campaigns.


## Events

| Name | Parameters | Description |
|------|------------|-------------|
| **Created** | `id` (uint256), `name` (string), `minLikes` (uint256), `endDate` (uint256), `brand` (address), `timestamp` (uint256) | Emitted when a new campaign is created |
| **Applied** | `id` (uint256), `user` (address), `timestamp` (uint256) | Emitted when a user applies to participate in a campaign |
| **Assigned** | `id` (uint256), `user` (address), `timestamp` (uint256) | Emitted when a user is assigned to a campaign |
| **Liked** | `id` (uint256), `user` (address), `timestamp` (uint256) | Emitted when a user likes a campaign |
| **Finished** | `id` (uint256), `user` (address), `payout` (uint256), `timestamp` (uint256) | Emitted when a campaign is finished |
| **BrandAdded** | `brand` (address), `timestamp` (uint256) | Emitted when a brand is added to the whitelist |
| **BrandRemoved** | `brand` (address), `name` (string) `description` (string) `timestamp` (uint256) | Emitted when a brand is removed from the whitelist |

## User Flow
1. User Authenticates with their Ethereum address.
2. Brand deploys a new campaign via the CampaignFactory.
   - Brand sends funds to the newly created campaign contract.
   - Campaign ownership remains with the factory deployer until the application window ends.
3. User applies for a campaign via the dApp.
   - User's address is added to the list of applicants.
4. After the application window closes, the brand has 72 hours to choose someone to complete this challenge.
    - Brand will call the `selectUser` function to select a user.
    - If no user is selected within 72 hours, the campaign is cancelled and funds are returned to the brand.
5. If a user is selected, ownership of the campaign is transferred back to the factory deployer, and we can start the campaign.
   - like goal is reached, user can call the `payout` function to withdraw the funds if time limit has not expired.
   - like goal is not reached, the campaign is cancelled and funds are returned to the brand.
6. The campaign is now complete and archived.

## Data Models

#### Campaign Details

| Field              | Type   
| ------------------ | ------ 
| name               | string 
| description        | string 
| image              | string 
| brand              | address 
| likeGoal           | uint   
| applicationWindow  | uint   
| campaignWindow     | uint   
| status             | enum   
| numApplications    | uint  
| applications       | mapping(address => CampaignApplication)
| numLikes           | uint   
| payoutAmount       | uint   
| selectedApplicant  | address  
| timeCampaignStart  | uint   
| timeCampaignEnd    | uint   

#### Campaign Stats

| Field           | Type   |
| --------------- | ------ |
| likeGoal        | uint   |
| numApplications | uint   |
| numLikes        | uint   |
| payoutAmount    | uint   |

#### Campaign Application

| Field       | Type     |
| ----------- | -------- |
| timestamp   | uint     |
| status      | enum     |


## Functions [CampaignFactory.sol](/contracts/Campaign.sol)

| Name | Parameters | Description |
|------|------------|-------------|



