import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Campaign Factory", function () {
  async function deployTipJar() {
    const [owner, otherAccount] = await ethers.getSigners();

    const TipJar = await ethers.getContractFactory("TipJar");
    const tips = await TipJar.deploy();
    const balance = await ethers.provider.getBalance(tips.address);

    return { tips, owner, otherAccount, balance };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { tips, owner } = await loadFixture(deployTipJar);

      expect(await tips.owner()).to.equal(owner.address);
    });

    it("Balance should be empty", async function () {
      const { balance } = await loadFixture(deployTipJar);
      expect(balance).to.equal(ethers.utils.parseEther("0"));
    });
  });

  describe("Create Campaign", function () {});

  describe("Like a Campaign", function () {});

  describe("Withdrawals", function () {});
});
