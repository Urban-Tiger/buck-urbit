require("dotenv").config();

const required = ["SEPOLIA_URL", "PRIVATE_KEY", "ETHERSCAN_API_KEY"];

console.log("Checking environment variables...");

let missing = [];
for (const env of required) {
  if (!process.env[env]) {
    missing.push(env);
  } else {
    console.log(`[OK] ${env} is set`);
  }
}

if (missing.length > 0) {
  console.log(`\n[ERROR] Missing environment variables: ${missing.join(", ")}`);
  console.log("\nPlease set them in your .env file or environment:");
  missing.forEach(env => {
    console.log(`${env}=your_value_here`);
  });
  process.exit(1);
} else {
  console.log("\n[SUCCESS] All required environment variables are set!");
}