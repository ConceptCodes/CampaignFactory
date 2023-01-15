import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Campaign Factory", function () {
  async function deploy() {
    const [owner, otherAccount] = await ethers.getSigners();

    const CampaignFactory = await ethers.getContractFactory("CampaignFactory");
    const contract = await CampaignFactory.deploy();
    const balance = await ethers.provider.getBalance(contract.address);
    const campaignCount = await contract._campaignIds();

    return { contract, owner, otherAccount, balance, campaignCount };
  }

  describe("Deployment", function () {
    it("Should set deployer to owner", async function () {
      const { contract, owner } = await loadFixture(deploy);
      expect(await contract.owner()).to.equal(owner.address);
    });

    it("Balance should be empty", async function () {
      const { balance } = await loadFixture(deploy);
      expect(balance).to.equal(ethers.utils.parseEther("0"));
    });

    it("There should be 0 campaigns", async function(){
      const { campaignCount } = await loadFixture(deploy);
      expect(campaignCount).to.equal(0);
    })
  });

  describe("Create Campaign", function () {
    it("Deny non brands", async function () {
      const { contract, owner } = await loadFixture(deploy);
      await expect(
        contract
          .connect(owner)
          .createCampaign(
            "Test Campaign",
            "Test Campaign Description",
            "Test Campaign Image",
            3,
            100
          )
      ).to.be.revertedWithCustomError(contract, "ValidationError");
        
    });
  });

  describe("Like a Campaign", function () {});

  describe("Withdrawals", function () {});

  describe("Access Control", function () {});
});
