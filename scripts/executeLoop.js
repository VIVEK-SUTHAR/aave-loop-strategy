const hre = require("hardhat");

async function main() {
  const contractAddress = "0xA15a33E45a0dc5C21898f92A48946559dCc7cD9e";
  const numLoops = 1;
  const ethAmount = hre.ethers.parseEther("0.1");

  const [signer] = await hre.ethers.getSigners();
  const AaveLoopStrategy = await hre.ethers.getContractFactory(
    "AaveLoopStrategy",
    signer
  );

  const contract = await AaveLoopStrategy.attach(contractAddress);

  console.log("Executing loop...");
  const tx = await contract.executeLoop(1000000, numLoops, {
    value: ethAmount, // Send ETH as msg.value
  });

  console.log("Transaction submitted. Waiting for confirmation...");
  const receipt = await tx.wait();

  console.log("Loop executed successfully!");
  console.log("Transaction details:", receipt);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
