require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ethers");

const PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true, // This enables the "via IR" mode
    },
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    goerli: {
      url: "https://goerli.infura.io/v3/YOUR_INFURA_PROJECT_ID",
      accounts: [PRIVATE_KEY]
    }
  }
};


// require("@nomicfoundation/hardhat-ethers");
// require("dotenv").config(); // Uncomment this

// const PRIVATE_KEY = process.env.PRIVATE_KEY; // Read from .env file

// module.exports = {
//   solidity: "0.8.28",
//   networks: {
//     localhost: {
//       url: "http://127.0.0.1:8545"
//     },
//     goerli: {
//       url: process.env.GOERLI_RPC_URL, // Also use environment variable for RPC URL
//       accounts: PRIVATE_KEY ? [PRIVATE_KEY] : []
//     }
//   }
// };