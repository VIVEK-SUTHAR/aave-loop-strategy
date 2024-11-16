require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
      },
      {
        version: "0.7.6",
      },
    ],
  },
  networks: {
    base: {
      url: "https://base-sepolia.g.alchemy.com/v2/fBWWVmE9-nfSRozFRH9tHmWGVTI-l_Hm",
      accounts: [process.env.PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: "YOUR_ETHERSCAN_API_KEY",
  },
};
