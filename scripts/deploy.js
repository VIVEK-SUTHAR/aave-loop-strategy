const hre = require("hardhat");

async function main() {
  const AaveLoopStrategy = await hre.ethers.getContractFactory(
    "AaveLoopStrategy"
  );

  console.log("Deploying AaveLoopStrategy...");
  const aaveLoopStrategy = await AaveLoopStrategy.deploy({
    gasLimit: 8000000,
  });
  console.log(aaveLoopStrategy);

  console.log("AaveLoopStrategy deployed to:", aaveLoopStrategy.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
