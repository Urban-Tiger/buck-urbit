const hre = require("hardhat");
const fs = require("fs");

const NEW_AZIMUTH_DEPLOY = false; // Set to true to verify Azimuth contracts (should match deploy script)

// Helper function to sleep
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function verifyContract(name, address, constructorArgs, contract = null) {
  console.log(`\nVerifying ${name}...`);

  try {
    const verifyParams = {
      address: address,
      constructorArguments: constructorArgs,
    };

    if (contract) {
      verifyParams.contract = contract;
    }

    await hre.run("verify:verify", verifyParams);
    console.log(`[SUCCESS] ${name} verified successfully`);

    // Sleep after each verification for Sepolia
    console.log("Waiting 10 seconds before next verification...");
    await sleep(10000);
  } catch (error) {
    if (error.message.includes("Already Verified")) {
      console.log(`[INFO] ${name} already verified`);
    } else if (error.message.includes("More than one contract was found")) {
      console.log(
        `[WARNING] ${name} needs contract specification - will retry with contract parameter`
      );
      throw error;
    } else {
      console.error(`[ERROR] ${name} verification failed:`, error.message);
      throw error;
    }
  }
}

async function main() {
  console.log("Starting verification with delays for Sepolia...");

  // Get the latest deployment file from deployments directory
  const deploymentsDir = "deployments";
  const files = fs
    .readdirSync(deploymentsDir)
    .filter((f) => f.startsWith("deployment-") && f.endsWith(".json"))
    .map(f => ({ 
      name: f, 
      path: `${deploymentsDir}/${f}`,
      stats: fs.statSync(`${deploymentsDir}/${f}`)
    }))
    .sort((a, b) => b.stats.mtime - a.stats.mtime)
    .map(f => f.name);

  if (files.length === 0) {
    console.error("[ERROR] No deployment files found!");
    process.exit(1);
  }

  const deploymentFile = files[0];
  const deploymentPath = `${deploymentsDir}/${deploymentFile}`;
  console.log(`Using deployment file: ${deploymentPath}`);

  const deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
  const contracts = deployment.contracts;
  const azimuthContracts = deployment.azimuthContracts;

  console.log("\nContracts to verify:");
  console.log("UrbitToken:", contracts.urbitToken);
  console.log("UstarToken:", contracts.ustarToken);
  console.log("UrbitVault:", contracts.urbitVault);
  console.log("Azimuth:", contracts.azimuth);
  console.log("Ecliptic:", contracts.ecliptic);
  if (azimuthContracts) {
    console.log("Polls:", azimuthContracts.polls);
    console.log("Claims:", azimuthContracts.claims);
  }

  // Wait a bit to let contracts settle on Sepolia
  console.log("\nWaiting 30 seconds for contracts to settle on Sepolia...");
  await sleep(30000);

  try {
    // Verify our main contracts first
    await verifyContract(
      "UrbitToken",
      contracts.urbitToken,
      [],
      "contracts/UrbitToken.sol:UrbitToken"
    );

    await verifyContract(
      "UstarToken",
      contracts.ustarToken,
      [],
      "contracts/UstarToken.sol:UstarToken"
    );

    await verifyContract("UrbitVault", contracts.urbitVault, [
      contracts.azimuth,
      contracts.urbitToken,
      contracts.ustarToken,
    ]);

    // Verify Azimuth contracts only if we deployed them fresh
    if (NEW_AZIMUTH_DEPLOY && azimuthContracts) {
      console.log("\nVerifying freshly deployed Azimuth contracts...");

      await verifyContract("Azimuth", contracts.azimuth, []);

      await verifyContract("Polls", azimuthContracts.polls, [2592000, 2592000]);

      await verifyContract("Claims", azimuthContracts.claims, [
        contracts.azimuth,
      ]);

      await verifyContract("Ecliptic", contracts.ecliptic, [
        "0x0000000000000000000000000000000000000000",
        contracts.azimuth,
        azimuthContracts.polls,
        azimuthContracts.claims,
        "0x0000000000000000000000000000000000000000",
      ]);
    } else if (!NEW_AZIMUTH_DEPLOY) {
      console.log(
        "\nSkipping Azimuth contract verification (using existing contracts)"
      );
    }

    console.log("\n[SUCCESS] ALL CONTRACTS VERIFIED SUCCESSFULLY!");
    console.log("\nEtherscan URLs:");
    console.log(
      `UrbitToken: https://sepolia.etherscan.io/address/${contracts.urbitToken}#code`
    );
    console.log(
      `UstarToken: https://sepolia.etherscan.io/address/${contracts.ustarToken}#code`
    );
    console.log(
      `UrbitVault: https://sepolia.etherscan.io/address/${contracts.urbitVault}#code`
    );

    if (NEW_AZIMUTH_DEPLOY) {
      console.log(
        `Azimuth: https://sepolia.etherscan.io/address/${contracts.azimuth}#code`
      );
      console.log(
        `Ecliptic: https://sepolia.etherscan.io/address/${contracts.ecliptic}#code`
      );

      if (azimuthContracts) {
        console.log(
          `Polls: https://sepolia.etherscan.io/address/${azimuthContracts.polls}#code`
        );
        console.log(
          `Claims: https://sepolia.etherscan.io/address/${azimuthContracts.claims}#code`
        );
      }
    } else {
      console.log(
        "\nUsing existing Azimuth contracts (not verified in this run):"
      );
      console.log(
        `Azimuth: https://sepolia.etherscan.io/address/${contracts.azimuth}#code`
      );
      console.log(
        `Ecliptic: https://sepolia.etherscan.io/address/${contracts.ecliptic}#code`
      );

      if (azimuthContracts) {
        console.log(
          `Polls: https://sepolia.etherscan.io/address/${azimuthContracts.polls}#code`
        );
        console.log(
          `Claims: https://sepolia.etherscan.io/address/${azimuthContracts.claims}#code`
        );
      }
    }
  } catch (error) {
    console.error("\n[ERROR] Verification process failed:", error.message);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
