const { ethers } = require("hardhat");

const NEW_AZIMUTH_DEPLOY = false; // Set to true to deploy fresh Azimuth contracts on testnet

async function main() {
  console.log("Starting deployment...");

  // Contract addresses on mainnet
  const MAINNET_AZIMUTH = "0x223c067f8cf28ae173ee5cafea60ca44c335fecb";
  const MAINNET_ECLIPTIC = "0x33EeCbf908478C10614626A9D304bfe18B78DD73";

  // Contract addresses on sepolia
  const SEPOLIA_AZIMUTH = "0xE6532b92148615418c1b4150dA4caC122b1C7F1a";
  const SEPOLIA_ECLIPTIC = "0xf49C4d09C0b98Fb2d199820eC99D22d39174D1A3";
  const SEPOLIA_POLLS = "0x45F07b804fF433D6631195b9E0889948eb5bfFc3";
  const SEPOLIA_CLAIMS = "0xC5001d979BC4e38dE8FDc8d9a08074Ba6c65f20F";

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance));

  // Get network information
  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name, "Chain ID:", network.chainId);

  let azimuthAddress, eclipticAddress;

  // Initialize deployment info object
  let deploymentInfo = {
    network: network.name,
    chainId: network.chainId.toString(),
    deployer: deployer.address,
    contracts: {},
    deployedAt: new Date().toISOString(),
  };

  if (network.chainId === 1n) {
    // Mainnet
    azimuthAddress = MAINNET_AZIMUTH;
    eclipticAddress = MAINNET_ECLIPTIC;
  } else if (network.chainId === 11155111n) {
    // Sepolia
    if (NEW_AZIMUTH_DEPLOY) {
      // Deploy our own Azimuth contracts for Sepolia testing
      console.log("Deploying fresh Azimuth contracts for Sepolia...");

      // Deploy Azimuth
      const Azimuth = await ethers.getContractFactory("Azimuth");
      const azimuthContract = await Azimuth.deploy();
      await azimuthContract.waitForDeployment();
      azimuthAddress = await azimuthContract.getAddress();
      console.log("Azimuth deployed to:", azimuthAddress);

      // Deploy Polls contract
      const Polls = await ethers.getContractFactory("Polls");
      const pollsContract = await Polls.deploy(2592000, 2592000); // 30 day periods
      await pollsContract.waitForDeployment();
      const pollsAddress = await pollsContract.getAddress();
      console.log("Polls deployed to:", pollsAddress);

      // Deploy Claims contract
      const Claims = await ethers.getContractFactory("Claims");
      const claimsContract = await Claims.deploy(azimuthAddress);
      await claimsContract.waitForDeployment();
      const claimsAddress = await claimsContract.getAddress();
      console.log("Claims deployed to:", claimsAddress);

      // Deploy Ecliptic
      const Ecliptic = await ethers.getContractFactory("Ecliptic");
      const eclipticContract = await Ecliptic.deploy(
        "0x0000000000000000000000000000000000000000",
        azimuthAddress,
        pollsAddress,
        claimsAddress,
        "0x0000000000000000000000000000000000000000"
      );
      await eclipticContract.waitForDeployment();
      eclipticAddress = await eclipticContract.getAddress();
      console.log("Ecliptic deployed to:", eclipticAddress);

      // Transfer ownership
      await azimuthContract.transferOwnership(eclipticAddress);
      await pollsContract.transferOwnership(eclipticAddress);
      console.log("Azimuth ownership transferred to Ecliptic");

      // Store additional contract addresses for verification
      deploymentInfo.azimuthContracts = {
        polls: pollsAddress,
        claims: claimsAddress,
      };
    } else {
      // Use existing Sepolia Azimuth contracts
      console.log("Using existing Sepolia Azimuth contracts...");
      azimuthAddress = SEPOLIA_AZIMUTH;
      eclipticAddress = SEPOLIA_ECLIPTIC;
      console.log("Azimuth address:", azimuthAddress);
      console.log("Ecliptic address:", eclipticAddress);
      console.log("Polls address:", SEPOLIA_POLLS);
      console.log("Claims address:", SEPOLIA_CLAIMS);

      // Store existing contract addresses for reference
      deploymentInfo.azimuthContracts = {
        polls: SEPOLIA_POLLS,
        claims: SEPOLIA_CLAIMS,
      };
    }
  } else {
    // For local testing, deploy real Azimuth contracts
    console.log(
      "Deploying Azimuth and Ecliptic contracts for local testing..."
    );

    // Deploy Azimuth
    const Azimuth = await ethers.getContractFactory("Azimuth");
    const azimuthContract = await Azimuth.deploy();
    await azimuthContract.waitForDeployment();
    azimuthAddress = await azimuthContract.getAddress();
    console.log("Azimuth deployed to:", azimuthAddress);

    // Deploy Polls contract
    const Polls = await ethers.getContractFactory("Polls");
    const pollsContract = await Polls.deploy(1209600, 1209600);
    await pollsContract.waitForDeployment();
    const pollsAddress = await pollsContract.getAddress();
    console.log("Polls deployed to:", pollsAddress);

    // Deploy Claims contract
    const Claims = await ethers.getContractFactory("Claims");
    const claimsContract = await Claims.deploy(azimuthAddress);
    await claimsContract.waitForDeployment();
    const claimsAddress = await claimsContract.getAddress();
    console.log("Claims deployed to:", claimsAddress);

    // Deploy Ecliptic
    const Ecliptic = await ethers.getContractFactory("Ecliptic");
    const eclipticContract = await Ecliptic.deploy(
      "0x0000000000000000000000000000000000000000",
      azimuthAddress,
      pollsAddress,
      claimsAddress,
      "0x0000000000000000000000000000000000000000"
    );
    await eclipticContract.waitForDeployment();
    eclipticAddress = await eclipticContract.getAddress();
    console.log("Ecliptic deployed to:", eclipticAddress);

    // Transfer Azimuth ownership to Ecliptic
    await azimuthContract.transferOwnership(eclipticAddress);
    console.log("Azimuth ownership transferred to Ecliptic");
  }

  // Deploy UrbitToken
  console.log("Deploying UrbitToken...");
  const UrbitToken = await ethers.getContractFactory("UrbitToken");
  const urbitToken = await UrbitToken.deploy();
  await urbitToken.waitForDeployment();
  const urbitTokenAddress = await urbitToken.getAddress();
  console.log("UrbitToken deployed to:", urbitTokenAddress);

  // Deploy UstarToken
  console.log("Deploying UstarToken...");
  const UstarToken = await ethers.getContractFactory("UstarToken");
  const ustarToken = await UstarToken.deploy();
  await ustarToken.waitForDeployment();
  const ustarTokenAddress = await ustarToken.getAddress();
  console.log("UstarToken deployed to:", ustarTokenAddress);

  // Deploy UrbitVault
  console.log("Deploying UrbitVault...");
  const UrbitVault = await ethers.getContractFactory("UrbitVault");
  const urbitVault = await UrbitVault.deploy(
    azimuthAddress,
    urbitTokenAddress,
    ustarTokenAddress
  );
  await urbitVault.waitForDeployment();
  const urbitVaultAddress = await urbitVault.getAddress();
  console.log("UrbitVault deployed to:", urbitVaultAddress);

  // Transfer ownership of token contracts to the vault
  console.log("Transferring UrbitToken ownership to vault...");
  await urbitToken.transferOwnership(urbitVaultAddress);
  console.log("UrbitToken ownership transferred");

  console.log("Transferring UstarToken ownership to vault...");
  await ustarToken.transferOwnership(urbitVaultAddress);
  console.log("UstarToken ownership transferred");

  console.log("\nDeployment Summary:");
  console.log("==================");
  console.log("UrbitToken:", urbitTokenAddress);
  console.log("UstarToken:", ustarTokenAddress);
  console.log("UrbitVault:", urbitVaultAddress);
  console.log("Azimuth:", azimuthAddress);
  console.log("Ecliptic:", eclipticAddress);

  // Save deployment addresses to file
  deploymentInfo.contracts = {
    urbitToken: urbitTokenAddress,
    ustarToken: ustarTokenAddress,
    urbitVault: urbitVaultAddress,
    azimuth: azimuthAddress,
    ecliptic: eclipticAddress,
  };

  const fs = require("fs");
  const path = require("path");

  const deploymentsDir = "deployments";
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }

  const deploymentFile = path.join(
    deploymentsDir,
    `deployment-${network.name}-${Date.now()}.json`
  );
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\nDeployment info saved to ${deploymentFile}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
