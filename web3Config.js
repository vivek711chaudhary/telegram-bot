const { ethers } = require("hardhat");
const {Web3} = require('web3');

// Set up the Web3 instance (optional, Hardhat's default ethers.js can also be used directly)
// const web3 = new Web3("http://localhost:8545");
const web3 = new Web3("http://127.0.0.1:8545");

// Load contract ABI and address
const contractAddress = '0x5FbDB2315678afecb367f032d93F642f64180aa3'; // Replace with your deployed contract address
const contractABI = require('../artifacts/contracts/MusicBattle.sol/MusicBattle.json').abi; // Replace with your contract's ABI file

// Create contract instance
const contract = new web3.eth.Contract(contractABI, contractAddress);

// Private key (for local transactions or if using hardhat accounts)
const privateKey = '0x5FbDB2315678afecb367f032d93F642f64180aa3'; // Use with caution, consider using a safer method in production

module.exports = { web3, contract, privateKey };

