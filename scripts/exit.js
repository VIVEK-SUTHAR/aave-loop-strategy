const hre = require("hardhat");

async function main() {
  const contractAddress = "0x0E4557C3456b583895A23Da18Bf89e3a9b6A14c2"; // Deployed contract address

  const [signer] = await hre.ethers.getSigners(); // Get the signer from Hardhat
  const AaveLoopStrategy = await hre.ethers.getContractFactory(
    "AaveLoopStrategy",
    signer
  );

  const contract = await AaveLoopStrategy.attach(contractAddress);

  console.log("Initiating emergency exit...");

  try {
    const tx = await contract.emergencyExit(); // Call emergencyExit function
    console.log("Transaction submitted. Waiting for confirmation...");

    const receipt = await tx.wait(); // Wait for the transaction to be mined
    console.log("Emergency exit executed successfully!");

    // Display transaction details
    console.log("Transaction hash:", receipt.transactionHash);
    console.log("Block number:", receipt.blockNumber);

    // Extract and display event logs (if any)
    receipt.events.forEach((event) => {
      if (event.event === "EmergencyExitExecuted") {
        console.log("Event detected: EmergencyExitExecuted");
        console.log(
          `- Total Collateral: ${hre.ethers.formatEther(
            event.args.totalCollateral
          )} ETH`
        );
        console.log(
          `- Total Debt: ${hre.ethers.formatEther(event.args.totalDebt)} USDC`
        );
      }
    });
  } catch (error) {
    console.error("Error executing emergency exit:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
