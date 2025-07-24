const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UrbitVault", function () {
  let urbitVault, urbitToken, ustarToken;
  let mockAzimuth, mockEcliptic;
  let owner, user1, user2;

  const PLANETS_PER_STAR = 65535;
  const STAR_ID = 256; // Example star ID
  const GALAXY_ID = 1; // Example galaxy ID (should fail)

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy mock Azimuth contract
    const MockAzimuth = await ethers.getContractFactory("MockAzimuth");
    mockAzimuth = await MockAzimuth.deploy();
    await mockAzimuth.waitForDeployment();

    // Deploy mock Ecliptic contract
    const MockEcliptic = await ethers.getContractFactory("MockEcliptic");
    mockEcliptic = await MockEcliptic.deploy();
    await mockEcliptic.waitForDeployment();

    // Deploy UrbitToken
    const UrbitToken = await ethers.getContractFactory("UrbitToken");
    urbitToken = await UrbitToken.deploy();
    await urbitToken.waitForDeployment();

    // Deploy UstarToken
    const UstarToken = await ethers.getContractFactory("UstarToken");
    ustarToken = await UstarToken.deploy();
    await ustarToken.waitForDeployment();

    // Set up mock azimuth to return ecliptic as owner
    await mockAzimuth.setContractOwner(await mockEcliptic.getAddress());

    // Deploy UrbitVault
    const UrbitVault = await ethers.getContractFactory("UrbitVault");
    urbitVault = await UrbitVault.deploy(
      await mockAzimuth.getAddress(),
      await urbitToken.getAddress(),
      await ustarToken.getAddress()
    );
    await urbitVault.waitForDeployment();

    // Transfer ownership of tokens to vault
    await urbitToken.transferOwnership(await urbitVault.getAddress());
    await ustarToken.transferOwnership(await urbitVault.getAddress());

    // Set up mock data for star
    await mockAzimuth.setPointSize(STAR_ID, 1); // Star size
    await mockAzimuth.setPointSize(GALAXY_ID, 0); // Galaxy size
    await mockAzimuth.setVirginStar(STAR_ID, true);
    await mockEcliptic.mint(user1.address, STAR_ID);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await urbitVault.owner()).to.equal(owner.address);
    });

    it("Should set the correct contract addresses", async function () {
      expect(await urbitVault.azimuth()).to.equal(
        await mockAzimuth.getAddress()
      );
      // ecliptic is now retrieved dynamically from azimuth.owner()
      // We can't directly check it since there's no ecliptic() getter
      expect(await urbitVault.urbitToken()).to.equal(
        await urbitToken.getAddress()
      );
      expect(await urbitVault.ustarToken()).to.equal(
        await ustarToken.getAddress()
      );
    });

    it("Should have correct constants", async function () {
      expect(await urbitVault.PLANETS_PER_STAR()).to.equal(PLANETS_PER_STAR);
    });
  });

  describe("Virgin Star Validation", function () {
    it("Should correctly identify virgin stars", async function () {
      expect(await urbitVault.isEligibleStar(STAR_ID)).to.be.true;
    });

    it("Should correctly identify non-virgin stars", async function () {
      await mockAzimuth.setVirginStar(STAR_ID, false);
      expect(await urbitVault.isEligibleStar(STAR_ID)).to.be.false;
    });

    it("Should reject stars with spawn proxy set", async function () {
      const l2Address = "0x1111111111111111111111111111111111111111"; // Example L2 address
      await mockAzimuth.setSpawnProxy(STAR_ID, l2Address);
      expect(await urbitVault.isEligibleStar(STAR_ID)).to.be.false;
    });
  });

  describe("Star Deposit", function () {
    beforeEach(async function () {
      await mockEcliptic
        .connect(user1)
        .approve(await urbitVault.getAddress(), STAR_ID);
    });

    it("Should allow depositing virgin stars", async function () {
      await expect(urbitVault.connect(user1).depositStar(STAR_ID))
        .to.emit(urbitVault, "StarDeposited")
        .withArgs(STAR_ID, user1.address);

      expect(await urbitVault.depositedStars(STAR_ID)).to.be.true;
    });

    it("Should mint correct amount of tokens", async function () {
      await urbitVault.connect(user1).depositStar(STAR_ID);

      expect(await urbitToken.balanceOf(user1.address)).to.equal(
        PLANETS_PER_STAR
      );
      expect(await ustarToken.balanceOf(user1.address)).to.equal(1);
    });

    it("Should transfer star to vault", async function () {
      await urbitVault.connect(user1).depositStar(STAR_ID);

      expect(await mockEcliptic.ownerOf(STAR_ID)).to.equal(
        await urbitVault.getAddress()
      );
    });

    it("Should revert if star is not virgin", async function () {
      await mockAzimuth.setVirginStar(STAR_ID, false);

      await expect(
        urbitVault.connect(user1).depositStar(STAR_ID)
      ).to.be.revertedWithCustomError(urbitVault, "StarNotVirgin");
    });

    it("Should revert if point is not a star", async function () {
      await mockEcliptic.mint(user1.address, GALAXY_ID);
      await mockEcliptic
        .connect(user1)
        .approve(await urbitVault.getAddress(), GALAXY_ID);

      await expect(
        urbitVault.connect(user1).depositStar(GALAXY_ID)
      ).to.be.revertedWithCustomError(urbitVault, "InvalidAzimuthPoint");
    });

    it("Should revert if star already deposited", async function () {
      await urbitVault.connect(user1).depositStar(STAR_ID);

      await expect(
        urbitVault.connect(user1).depositStar(STAR_ID)
      ).to.be.revertedWithCustomError(urbitVault, "StarAlreadyDeposited");
    });

    it("Should revert if star has spawn proxy set", async function () {
      const l2Address = "0x1111111111111111111111111111111111111111"; // Example L2 address
      await mockAzimuth.setSpawnProxy(STAR_ID, l2Address);
      await mockEcliptic
        .connect(user1)
        .approve(await urbitVault.getAddress(), STAR_ID);

      await expect(
        urbitVault.connect(user1).depositStar(STAR_ID)
      ).to.be.revertedWithCustomError(urbitVault, "StarNotVirgin");
    });
  });

  describe("Star Redemption", function () {
    beforeEach(async function () {
      await mockEcliptic
        .connect(user1)
        .approve(await urbitVault.getAddress(), STAR_ID);
      await urbitVault.connect(user1).depositStar(STAR_ID);
    });

    it("Should allow redeeming stars with correct tokens", async function () {
      await urbitToken
        .connect(user1)
        .approve(await urbitVault.getAddress(), PLANETS_PER_STAR);
      await ustarToken.connect(user1).approve(await urbitVault.getAddress(), 1);

      await expect(urbitVault.connect(user1).redeemStar(STAR_ID))
        .to.emit(urbitVault, "StarRedeemed")
        .withArgs(STAR_ID, user1.address);

      expect(await urbitVault.depositedStars(STAR_ID)).to.be.false;
    });

    it("Should burn tokens and transfer star back", async function () {
      await urbitToken
        .connect(user1)
        .approve(await urbitVault.getAddress(), PLANETS_PER_STAR);
      await ustarToken.connect(user1).approve(await urbitVault.getAddress(), 1);

      await urbitVault.connect(user1).redeemStar(STAR_ID);

      expect(await urbitToken.balanceOf(user1.address)).to.equal(0);
      expect(await ustarToken.balanceOf(user1.address)).to.equal(0);
      expect(await mockEcliptic.ownerOf(STAR_ID)).to.equal(user1.address);
    });

    it("Should revert if star not deposited", async function () {
      await expect(
        urbitVault.connect(user1).redeemStar(999)
      ).to.be.revertedWithCustomError(urbitVault, "StarNotDeposited");
    });

    it("Should revert if insufficient URBIT tokens", async function () {
      await urbitToken.connect(user1).transfer(user2.address, 1);

      await expect(
        urbitVault.connect(user1).redeemStar(STAR_ID)
      ).to.be.revertedWithCustomError(urbitVault, "InsufficientTokens");
    });

    it("Should revert if insufficient USTAR tokens", async function () {
      await ustarToken.connect(user1).transfer(user2.address, 1);

      await expect(
        urbitVault.connect(user1).redeemStar(STAR_ID)
      ).to.be.revertedWithCustomError(urbitVault, "InsufficientTokens");
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to pause", async function () {
      await urbitVault.pause();
      expect(await urbitVault.paused()).to.be.true;
    });

    it("Should allow owner to unpause", async function () {
      await urbitVault.pause();
      await urbitVault.unpause();
      expect(await urbitVault.paused()).to.be.false;
    });

    it("Should prevent deposits when paused", async function () {
      await mockEcliptic
        .connect(user1)
        .approve(await urbitVault.getAddress(), STAR_ID);
      await urbitVault.pause();

      await expect(
        urbitVault.connect(user1).depositStar(STAR_ID)
      ).to.be.revertedWithCustomError(urbitVault, "EnforcedPause");
    });
  });

  describe("Access Control", function () {
    it("Should revert if non-owner tries to pause", async function () {
      await expect(
        urbitVault.connect(user1).pause()
      ).to.be.revertedWithCustomError(urbitVault, "OwnableUnauthorizedAccount");
    });
  });

  describe("ERC20Permit Functionality", function () {
    beforeEach(async function () {
      await mockEcliptic
        .connect(user1)
        .approve(await urbitVault.getAddress(), STAR_ID);
      await urbitVault.connect(user1).depositStar(STAR_ID);
    });

    it("Should support permit on UrbitToken", async function () {
      const domain = {
        name: "URBIT",
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: await urbitToken.getAddress(),
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      };

      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      const nonce = await urbitToken.nonces(user1.address);

      const values = {
        owner: user1.address,
        spender: await urbitVault.getAddress(),
        value: PLANETS_PER_STAR,
        nonce: nonce,
        deadline: deadline,
      };

      const signature = await user1.signTypedData(domain, types, values);
      const { v, r, s } = ethers.Signature.from(signature);

      // Use permit to approve
      await urbitToken.permit(
        user1.address,
        await urbitVault.getAddress(),
        PLANETS_PER_STAR,
        deadline,
        v,
        r,
        s
      );

      // Verify approval was set
      expect(
        await urbitToken.allowance(user1.address, await urbitVault.getAddress())
      ).to.equal(PLANETS_PER_STAR);
    });

    it("Should support permit on UstarToken", async function () {
      const domain = {
        name: "USTAR",
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: await ustarToken.getAddress(),
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      };

      const deadline = Math.floor(Date.now() / 1000) + 3600;
      const nonce = await ustarToken.nonces(user1.address);

      const values = {
        owner: user1.address,
        spender: await urbitVault.getAddress(),
        value: 1,
        nonce: nonce,
        deadline: deadline,
      };

      const signature = await user1.signTypedData(domain, types, values);
      const { v, r, s } = ethers.Signature.from(signature);

      await ustarToken.permit(
        user1.address,
        await urbitVault.getAddress(),
        1,
        deadline,
        v,
        r,
        s
      );

      expect(
        await ustarToken.allowance(user1.address, await urbitVault.getAddress())
      ).to.equal(1);
    });

    it("Should allow redemption with permit (gasless approval)", async function () {
      // Create permits for both tokens
      const urbitDomain = {
        name: "URBIT",
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: await urbitToken.getAddress(),
      };

      const ustarDomain = {
        name: "USTAR",
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: await ustarToken.getAddress(),
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      };

      const deadline = Math.floor(Date.now() / 1000) + 3600;
      const urbitNonce = await urbitToken.nonces(user1.address);
      const ustarNonce = await ustarToken.nonces(user1.address);

      // Sign URBIT permit
      const urbitValues = {
        owner: user1.address,
        spender: await urbitVault.getAddress(),
        value: PLANETS_PER_STAR,
        nonce: urbitNonce,
        deadline: deadline,
      };
      const urbitSignature = await user1.signTypedData(
        urbitDomain,
        types,
        urbitValues
      );
      const urbitSig = ethers.Signature.from(urbitSignature);

      // Sign USTAR permit
      const ustarValues = {
        owner: user1.address,
        spender: await urbitVault.getAddress(),
        value: 1,
        nonce: ustarNonce,
        deadline: deadline,
      };
      const ustarSignature = await user1.signTypedData(
        ustarDomain,
        types,
        ustarValues
      );
      const ustarSig = ethers.Signature.from(ustarSignature);

      // Use redeemStarWithPermit (single transaction)
      await expect(
        urbitVault
          .connect(user1)
          .redeemStarWithPermit(
            STAR_ID,
            deadline,
            urbitSig.v,
            urbitSig.r,
            urbitSig.s,
            deadline,
            ustarSig.v,
            ustarSig.r,
            ustarSig.s
          )
      )
        .to.emit(urbitVault, "StarRedeemed")
        .withArgs(STAR_ID, user1.address);

      // Verify redemption completed
      expect(await urbitVault.depositedStars(STAR_ID)).to.be.false;
      expect(await mockEcliptic.ownerOf(STAR_ID)).to.equal(user1.address);
      expect(await urbitToken.balanceOf(user1.address)).to.equal(0);
      expect(await ustarToken.balanceOf(user1.address)).to.equal(0);
    });

    it("Should revert with expired permit deadline", async function () {
      const expiredDeadline = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago

      await expect(
        urbitToken.permit(
          user1.address,
          await urbitVault.getAddress(),
          PLANETS_PER_STAR,
          expiredDeadline,
          27, // dummy v
          ethers.ZeroHash, // dummy r
          ethers.ZeroHash // dummy s
        )
      ).to.be.revertedWithCustomError(urbitToken, "ERC2612ExpiredSignature");
    });
  });
});
