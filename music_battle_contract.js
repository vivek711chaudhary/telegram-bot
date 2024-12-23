const { web3, contract, privateKey } = require("./web3Config.js");

async function voteTrack(battleId, trackNumber, userAddress, paymentAmount) {
  try {
    // Validate inputs
    if (!battleId || ![1, 2].includes(trackNumber) || !userAddress || !paymentAmount) {
      throw new Error('Invalid battle ID, track number, user address, or payment amount');
    }

    // Check if the user has already voted in this battle
    const hasVoted = await contract.methods.battleVoters(battleId, userAddress).call();
    if (hasVoted) {
      console.log("You have already voted in this battle.");
      return { message: "You have already voted in this battle." }; // Exit if the user has already voted
    }

    // // Fetch battle details
    const battleDetails = await contract.methods.getBattleDetails(battleId).call();
    const battleRunningStatus = battleDetails.isActive;
    if (!battleRunningStatus) {
      console.log("Battle has stopped!");
      return { message: "Battle has stopped!" };
    }

    // Convert payment amount to Wei
    const paymentInWei = web3.utils.toWei(paymentAmount.toString(), 'ether');

    // Log user balance before transaction
    const balanceBefore = await web3.eth.getBalance(userAddress);
    console.log("User's balance before transaction in Voting function:", web3.utils.fromWei(balanceBefore, 'ether'), "ETH");

    // Prepare vote transaction
    const tx = contract.methods.vote(battleId, trackNumber, userAddress, paymentInWei);

    // Estimate gas
    const gas = await tx.estimateGas({ from: userAddress, value: paymentInWei });

    // Send transaction
    const receipt = await tx.send({
      from: userAddress,
      gas,
      value: paymentInWei,
    });

    // Log user balance after transaction
    const balanceAfter = await web3.eth.getBalance(userAddress);
    console.log("User's balance after transaction in Voting function:", web3.utils.fromWei(balanceAfter, 'ether'), "ETH");

    console.log('Transaction Hash:', receipt.transactionHash);

    return {
      transactionHash: receipt.transactionHash,
    };
  } catch (error) {
    console.error('Vote Track Error:', error);

    // Attempt to extract the specific error message
    const errorMessage = error?.cause?.cause?.errorArgs?.message || error.message || "Unknown error occurred";

    if (errorMessage.includes("Battle voting period has ended")) {
      return { message: "Battle voting period has ended" };
    }

    // Rethrow error if not handled
    throw new Error(`Vote Track Error: ${errorMessage}`);
  }
}


async function getBattleDetails(battleId) {
  try {
    // Validate input
    if (!battleId) {
      throw new Error('Battle ID must be provided');
    }

    // Call contract method to get battle details
    const result = await contract.methods.getBattleDetails(battleId).call();

    console.log('result:--------------------',result)
    return {
      track1: result.track1,
      track2: result.track2,
      votesTrack1: result.votesTrack1.toString(),
      
      votesTrack2: result.votesTrack2.toString(),
      timestamp: result.timestamp.toString(),

      isActive: result.isActive,
      winner: result.winner,
      
    };
  } catch (error) {
    console.error('Get Battle Details Error:', error);
    throw error;
  }
}

async function getTotalVoters(battleId) {
  try {
    // Validate input
    if (!battleId) {
      throw new Error('Battle ID must be provided');
    }

    // Call contract method to get total voters
    const totalVoters = await contract.methods.getTotalVoters(battleId).call();

    console.log('totalVoters:-----------------------',totalVoters.toString())
    return totalVoters.toString();
  } catch (error) {
    console.error('Get Total Voters Error:', error);
    throw error;
  }
}
async function getVotersList(battleId) {
  try {
    // Validate input
    if (!battleId) {
      throw new Error('Battle ID must be provided');
    }

    // Call contract method to get total voters
    const votersList = await contract.methods.votersList(battleId).call();

    console.log('votersList:-----------------------')
    for(let i=0;i<votersList.length;i++){
      console.log(votersList[i]);
    }

    return votersList;
  } catch (error) {
    console.error('Get Voters List Error:', error);
    throw error;
  }
}

async function getBattleVotes(battleId) {
  try {
    // Validate input
    if (!battleId) {
      throw new Error('Battle ID must be provided');
    }

    // Call contract method to get battle votes
    const result = await contract.methods.getBattleVotes(battleId).call();

    console.log('track1Votes:-------------',result.track1Votes.toString())
    console.log('track2Votes:-------------',result.track2Votes.toString())
    return {
      track1Votes: result.track1Votes.toString(),
      track2Votes: result.track2Votes.toString()
    };
  } catch (error) {
    console.error('Get Battle Votes Error:', error);
    throw error;
  }
}

async function startBattle(track1, track2, creatorTrack1, creatorTrack2, userAddress, paymentAmount) {
  try {
    // Validate input
    if (!track1 || !track2) {
      throw new Error('Both tracks must be provided.');
    }
    if (!creatorTrack1 || !creatorTrack2) {
      throw new Error('Both creator addresses must be provided.');
    }
    if (!userAddress) {
      throw new Error('User address must be provided.');
    }
    if (!paymentAmount || isNaN(paymentAmount) || paymentAmount <= 0) {
      throw new Error('A valid payment amount must be provided.');
    }

    // Convert payment amount to Wei
    const paymentInWei = web3.utils.toWei(paymentAmount.toString(), 'ether');

    // Log user balance before transaction
    const balanceBefore = await web3.eth.getBalance(userAddress);
    console.log("User's balance before transaction:", web3.utils.fromWei(balanceBefore, 'ether'), "ETH");

    // Prepare transaction
    const tx = contract.methods.createBattle(track1, track2, creatorTrack1, creatorTrack2);

    // Estimate gas
    const gas = await tx.estimateGas({
      from: userAddress,
      value: paymentInWei // Include payment in gas estimation
    });

    // Send transaction
    const receipt = await tx.send({
      from: userAddress,
      gas,
      value: paymentInWei // Include payment as value
    });

    // Log user balance after transaction
    const balanceAfter = await web3.eth.getBalance(userAddress);
    console.log("User's balance after transaction:", web3.utils.fromWei(balanceAfter, 'ether'), "ETH");

    // Extract battle ID from events
    const battleCreatedEvent = receipt.events?.BattleCreated;
    const battleId = battleCreatedEvent ? battleCreatedEvent.returnValues.battleId : null;

    console.log("Battle ID:", battleId);
    console.log("Transaction Hash:", receipt.transactionHash);

    // Schedule the getWinner function after 1 minute
    if (battleId) {
      console.log(`Scheduling getWinner for battle ID: ${battleId}`);
      console.log("Close battle function will be get implemented Now : ********************************************** in 1 minute ***************************************** ")
      setTimeout(() => getWinner(battleId), 15*1000);
    }

    return {
      balanceBefore: web3.utils.fromWei(balanceBefore, 'ether'),
      balanceAfter: web3.utils.fromWei(balanceAfter, 'ether'),
      battleId: battleId ? battleId.toString() : null,
      transactionHash: receipt.transactionHash
    };
  } catch (error) {
    console.error('Battle Creation Error:', error);
    throw error;
  }
}

async function getWinner(battleId) {
  try {
    if (!battleId) {
      throw new Error("Battle ID is required");
    }

    console.log(
      `Battle no ${battleId} is now closing $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$`
    );

    // Fetch the final result of the battle
    const finalResult = await contract.methods.closeBattle(battleId).call();

    console.log("Result is this:----------------------", finalResult);

    // Extract data from the result
    const result = finalResult["0"];
    const resultMessage = finalResult["1"];

    let part1 = "Match Ties, Money will be distributed to both. All voters are winners.";
    let winnerVotersList = [];

    // Determine the winner and fetch the voters list accordingly
    if (result === 1n) { // Using string comparison because call() may return strings
      part1 = "Track 1 is the winner";
      try {
        winnerVotersList = await contract.methods.getSpecificTrackVoters(result, battleId).call();
      } catch (err) {
        console.error("Error in fetching the Track 1 winner voters list:", err);
      }
    } else if (result == 2n) {
      part1 = "Track 2 is the winner";
      try {
        winnerVotersList = await contract.methods.getSpecificTrackVoters(result, battleId).call();
      } catch (err) {
        console.error("Error in fetching the Track 2 winner voters list:", err);
      }
    } else {
      try {
        winnerVotersList = await contract.methods.votersList(battleId).call();
      } catch (err) {
        console.error("Error in fetching the voters list for a tie:", err);
      }
    }

    // Return the final results
    return {
      part1,
      winnerVotersList,
      resultMessage,
    };
  } catch (error) {
    console.error("Get Winner Error:", error.message || error);
    throw error;
  }
}



function transformString(input) {
  if (input.length <= 4) {
    return input; // Return the original string if it's too short
  }

  const firstPart = input.substring(0, 4); // Extract the first 4 characters
  const remainingPart = input.substring(4); // Extract the remaining characters
  return `${firstPart}.${remainingPart}`; // Concatenate with "."
}
async function getBattleCount() {
  try {
    // Call contract method to get battle count
    const battleCount = await contract.methods.battleCount().call();

    console.log('battleCount:---------------------',battleCount.toString())
    return battleCount.toString();
  } catch (error) {
    console.error('Get Battle Count Error:', error);
    throw error;
  }
}
async function func1() {
  try {
    // Call contract method to get battle count
    const balance = await contract.methods.getBalance().call();
    // const str = transformString(balance.toString())
    console.log('balance:---------------------: ',balance.toString())
    return balance.toString()
  } catch (error) {
    console.error('Get Account Balance Error:', error);
    throw error;
  }
}

async function transferAmount(amount, userAddress, senderAddress) {  // Add senderAddress parameter
  try {
    if (!amount || amount <= 0) {
      console.log("Please provide a valid amount");
      return;
    }

    // Convert amount to Wei if it's in ETH
    const amountInWei = web3.utils.toWei(amount.toString(), 'ether');

    // Log contract balance before transaction
    const contractBalance = await web3.eth.getBalance(contract.options.address);
    console.log("Contract balance before:", web3.utils.fromWei(contractBalance, 'ether'), "ETH");

    // Call the contract method with sender's address
    const resValue = await contract.methods
      .transferFundsFromContractToOwner(amountInWei, userAddress)
      .send({ 
        from: senderAddress,  // The actual caller's address (owner/creator)
        gas: 300000
      });

    // Log balances after transaction
    const contractBalanceAfter = await web3.eth.getBalance(contract.options.address);
    const userBalanceAfter = await web3.eth.getBalance(userAddress);
    
    console.log("Contract balance after:", web3.utils.fromWei(contractBalanceAfter, 'ether'), "ETH");
    console.log("User balance after:", web3.utils.fromWei(userBalanceAfter, 'ether'), "ETH");

    return resValue;
  } catch (err) {
    console.error("Transaction failed:", err);
    throw err;
  }
}
module.exports = { 
  startBattle, 
  voteTrack, 
  getBattleDetails,
  getTotalVoters,
  getBattleVotes,
  getBattleCount,
  getWinner,
  getVotersList,
  func1,
  transferAmount
};
