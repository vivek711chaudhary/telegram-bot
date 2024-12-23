// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function getRoundData(uint80 _roundId) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

contract MusicBattle {

    AggregatorV3Interface internal timeFeed;
    uint256 public constant MAX_BATTLES = 1000;
    uint256 public constant MAX_BATTLE_DURATION = 1 minutes;
    uint256 public constant STARTING_FEES = 10 ether;
    uint256 constant SCALE = 10**18;

    struct Battle {
        uint256 id;
        string track1;
        string track2;
        address creatorTrack1;
        address creatorTrack2;
        uint256 votesTrack1;
        uint256 votesTrack2;
        mapping(address => bool) hasVoted;
        address[] voters;
        address[] votersOfTrack1;
        address[] votersOfTrack2;
        uint256 timestamp;
        uint256 endTime;  // New field for Oracle-based end time
        bool isActive;
        address winner;
        address battleCreator;
        uint256 startingFees;
        uint256 amountGivenByTrack1Voters;
        uint256 amountGivenByTrack2Voters;
    }

    bool useOracleTime=true;

    uint256 public battleCount = 0;
    mapping(uint256 => Battle) public battles;
    address owner;

    event BattleCreated(uint256 indexed battleId, string track1, string track2, address creatorTrack1, address creatorTrack2, uint256 timestamp, uint256 endTime);
    event VoteCast(uint256 indexed battleId, uint256 trackNumber, address indexed voter);
    event BattleEnded(uint256 indexed battleId, address winner);
    event RewardPaid(address indexed recipient, uint256 amount);
    event FundsTransferredToOwner(uint256 amount, address indexed recipient);
    event BattleConcluded(uint256 indexed battleId, string winningTrack, address winner, address[] voters, bool isTie);

     constructor(address _timeFeedAddress) {
        owner = msg.sender;
        if (_timeFeedAddress != address(0)) {
            timeFeed = AggregatorV3Interface(_timeFeedAddress);
            useOracleTime = true;
        } else {
            useOracleTime = false;
        }
    }

     function getCurrentTime() public view returns (uint256) {
        if (useOracleTime) {
            try timeFeed.latestRoundData() returns (
                uint80 roundId,
                int256 answer,
                uint256 startedAt,
                uint256 updatedAt,
                uint80 answeredInRound
            ) {
                return startedAt;
            } catch {
                return block.timestamp;
            }
        }
        return block.timestamp;
    }

    modifier onlyOwnerOrCreator() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    function createBattle(string memory track1, string memory track2, address creatorTrack1, address creatorTrack2) public payable returns (uint256) {
        require(msg.value > 0, "Payment is required to start a battle.");
        require(bytes(track1).length > 0 && bytes(track2).length > 0, "Tracks cannot be empty");
        require(battleCount < MAX_BATTLES, "Maximum battle limit reached");

        uint256 startTime = getCurrentTime();
        uint256 endTime = startTime + MAX_BATTLE_DURATION;

        
        battleCount++;
        Battle storage newBattle = battles[battleCount];
        newBattle.id = battleCount;
        newBattle.track1 = track1;
        newBattle.track2 = track2;
        newBattle.creatorTrack1 = creatorTrack1;
        newBattle.creatorTrack2 = creatorTrack2;
        newBattle.timestamp = startTime;
        newBattle.endTime = endTime;
        newBattle.isActive = true;
        newBattle.startingFees = msg.value;
        newBattle.battleCreator = msg.sender;
        // newBattle.startingFees = STARTING_FEES;
        // newBattle.rewardAmount = REWARD_AMOUNT;

        emit BattleCreated(battleCount, track1, track2,creatorTrack1,creatorTrack2, startTime,endTime);
        console.log('Battle Created with ID:', battleCount);
        console.log("Battle timestamp is:",newBattle.timestamp);
        return battleCount;
    }

    function vote(uint256 battleId, uint256 trackNumber, address userAddress) public payable{
        // console.log("Intial Balance of contract:", address(this).balance/1000000000000000000);
        require(msg.value > 0, "Payment is required to start a battle.");
        require(battleId > 0 && battleId <= battleCount, "Battle does not exist");
        Battle storage battle = battles[battleId];

        uint256 currentTime = getCurrentTime();
        // Ensure battle is active and voting period is still ongoing
        require(battle.isActive, "Battle has ended");
        require(currentTime <= battle.endTime, "Battle voting period has ended");

        require(trackNumber == 1 || trackNumber == 2, "Invalid track number");
        require(userAddress != address(0), "Invalid user address");
        require(!battle.hasVoted[userAddress], "You have already voted");

        battle.hasVoted[userAddress] = true;
        battle.voters.push(userAddress);

        console.log("Voter with address:",userAddress,"has voted");
        if (trackNumber == 1) {
            battle.votesTrack1++;
            battle.votersOfTrack1.push(userAddress);
            console.log("voter 1 intial balance:",userAddress.balance/1000000000000000000);
            battle.amountGivenByTrack1Voters+=msg.value;
            console.log("voter 1 after balance:",userAddress.balance/1000000000000000000);
        } else {
            battle.votesTrack2++;
            battle.votersOfTrack2.push(userAddress);
            console.log("voter 1 intial balance:",userAddress.balance/1000000000000000000);
            battle.amountGivenByTrack2Voters+=msg.value;
            console.log("voter 1 after balance:",userAddress.balance/1000000000000000000);
        }

        console.log("Amount we have received from the Voter:",msg.value/1000000000000000000);
        console.log("Balance of contract :",address(this).balance/1000000000000000000);
        emit VoteCast(battleId, trackNumber, userAddress);
    }

   
 // Add these helper functions at the start of your contract, before the main function
function uint2str(uint256 _i) internal pure returns (string memory str) {
    if (_i == 0) {
        return "0";
    }
    uint256 j = _i;
    uint256 length;
    while (j != 0) {
        length++;
        j /= 10;
    }
    bytes memory bstr = new bytes(length);
    uint256 k = length;
    j = _i;
    while (j != 0) {
        bstr[--k] = bytes1(uint8(48 + j % 10));
        j /= 10;
    }
    str = string(bstr);
}

function bool2str(bool _b) internal pure returns (string memory) {
    return _b ? "true" : "false";
}

function addressToString(address _addr) internal pure returns (string memory) {
    bytes32 value = bytes32(uint256(uint160(_addr)));
    bytes memory alphabet = "0123456789abcdef";
    bytes memory str = new bytes(42);
    str[0] = "0";
    str[1] = "x";
    for (uint256 i = 0; i < 20; i++) {
        str[2+i*2] = alphabet[uint8(value[i + 12] >> 4)];
        str[3+i*2] = alphabet[uint8(value[i + 12] & 0x0f)];
    }
    return string(str);
}


function closeBattle(uint256 battleId) public returns (uint256, string memory) {
    string memory returnData = "";
    uint256 w = address(this).balance;
    
    returnData = string(abi.encodePacked(returnData, "Intial Balance of contract:", uint2str(address(this).balance/1000000000000000000), "\n"));
    returnData = string(abi.encodePacked(returnData, "Attempting to close battle with ID: ", uint2str(battleId), "\n"));
    
    require(battleId > 0 && battleId <= battleCount, "Battle does not exist");
    Battle storage battle = battles[battleId];

    returnData = string(abi.encodePacked(returnData, "Battle active state: ", bool2str(battle.isActive), "\n"));
    require(battle.isActive, "Battle already ended");

    uint256 currentTime = getCurrentTime();
    returnData = string(abi.encodePacked(returnData, "Current block timestamp: ", uint2str(currentTime), "\n"));
    returnData = string(abi.encodePacked(returnData, "Battle end time: ", uint2str(battle.endTime), "\n"));

    returnData = string(abi.encodePacked(returnData, 
        "Amount Received from Track 1 voters:", uint2str(battle.amountGivenByTrack1Voters/1000000000000000000), "\n",
        "Amount Received from Track 2 voters:", uint2str(battle.amountGivenByTrack2Voters/1000000000000000000), "\n"
    ));

    uint256 totalAmountHoldByBattle = battle.amountGivenByTrack1Voters + battle.amountGivenByTrack2Voters + battle.startingFees;
    returnData = string(abi.encodePacked(returnData, "Total amount the Battle holds:", uint2str(totalAmountHoldByBattle/1000000000000000000), "\n"));

    if (battle.votesTrack1 > battle.votesTrack2) {
        returnData = string(abi.encodePacked(returnData, "Track 1 is the winner\n"));
        uint256 amountGivenToEachWinnerVoter = battle.amountGivenByTrack1Voters + (battle.amountGivenByTrack2Voters)/2;
        amountGivenToEachWinnerVoter /= battle.votesTrack1;
        uint256 amountToGivenCreator = (battle.amountGivenByTrack2Voters * (300000000000000000)) / SCALE;
        
        if(battle.votesTrack2 == 0) {
            amountGivenToEachWinnerVoter = (battle.amountGivenByTrack1Voters*8)/10;
            amountGivenToEachWinnerVoter /= battle.votesTrack1;
            amountToGivenCreator = (battle.amountGivenByTrack1Voters*18)/100;
        }

        returnData = string(abi.encodePacked(returnData, 
            "Amount will be given to each voter:", uint2str(amountGivenToEachWinnerVoter/1000000000000000000), "\n",
            "Amount will be given to Winner Track Creator:", uint2str(amountToGivenCreator/1000000000000000000), "\n",
            "Transferring reward to Track Creator\n",
            "Winner balance before: ", uint2str(battle.creatorTrack1.balance/1000000000000000000), "\n"
        ));

        uint256 x = battle.creatorTrack1.balance;
        payable(battle.creatorTrack1).transfer(amountToGivenCreator);
        
        returnData = string(abi.encodePacked(returnData, 
            "Track 1 Creator receives : ", uint2str(amountToGivenCreator/1000000000000000000), "\n",
            "Winner balance after: ", uint2str(battle.creatorTrack1.balance/1000000000000000000), "\n"
        ));

        uint256 difference = (battle.creatorTrack1.balance-x)/1000000000000000000;
        returnData = string(abi.encodePacked(returnData, "Difference in winner's balance: ", uint2str(difference), "\n"));

        if(difference == 0) {
            returnData = string(abi.encodePacked(returnData, 
                "Money is reverted back to the contract\n",
                "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
            ));
        }

        returnData = string(abi.encodePacked(returnData, 
            "Transferring reward to winner voters\n",
            "battle.votesTrack1: ", uint2str(battle.votesTrack1), "\n"
        ));
        
        require(battle.votersOfTrack1.length >= battle.votesTrack1, "Voters array length mismatch");
        for(uint i=0; i<battle.votesTrack1; i++) {
            require(battle.votersOfTrack1[i] != address(0), "Invalid voter address");
            returnData = string(abi.encodePacked(returnData, 
                "Winner Voter Number:", uint2str(i), "Winner Voter balance before: ", uint2str(battle.votersOfTrack1[i].balance/1000000000000000000), "\n"
            ));
            
            uint256 y = battle.votersOfTrack1[i].balance;
            payable(battle.votersOfTrack1[i]).transfer(amountGivenToEachWinnerVoter);
            
            returnData = string(abi.encodePacked(returnData, 
                "Amount recieved by the voter No:", uint2str(i), " : ", uint2str(amountGivenToEachWinnerVoter/1000000000000000000), "\n",
                "Winner Voter Number:", uint2str(i), "Winner Voter balance after: ", uint2str(battle.votersOfTrack1[i].balance/1000000000000000000), "\n"
            ));
            
            difference = (battle.votersOfTrack1[i].balance-y)/1000000000000000000;
            returnData = string(abi.encodePacked(returnData, "Difference in voter's balance: ", uint2str(difference), "\n"));
            
            if(difference == 0) {
                returnData = string(abi.encodePacked(returnData, 
                    "Money is reverted back to the contract\n",
                    "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
                ));
            }
        }

        battle.isActive = false;
        emit BattleEnded(battleId, battle.creatorTrack1);
        emit BattleConcluded(battleId, "Track 1 Won", battle.creatorTrack1, battle.voters, true);

        returnData = string(abi.encodePacked(returnData, 
            "Remaining Balance Left on contract:", uint2str(address(this).balance/1000000000000000000), "\n"
        ));
        
        difference = (w-address(this).balance)/1000000000000000000;
        returnData = string(abi.encodePacked(returnData, "Difference in contract Balance :", uint2str(difference), "\n"));
        
        if(difference == 0) {
            returnData = string(abi.encodePacked(returnData, 
                "Money is reverted back to the contract\n",
                "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
            ));
        }
        return (1, returnData);
    } 
    else if (battle.votesTrack1 < battle.votesTrack2) {
        returnData = string(abi.encodePacked(returnData, "Track 2 is the winner\n"));
        uint256 amountGivenToEachWinnerVoter = battle.amountGivenByTrack2Voters + (battle.amountGivenByTrack1Voters)/2;
        amountGivenToEachWinnerVoter /= battle.votesTrack2;
        uint256 amountToGivenCreator = (battle.amountGivenByTrack1Voters * (300000000000000000)) / SCALE;

        if(battle.votesTrack1 == 0) {
            amountGivenToEachWinnerVoter = (battle.amountGivenByTrack2Voters*8)/10;
            amountGivenToEachWinnerVoter /= battle.votesTrack2;
            amountToGivenCreator = (battle.amountGivenByTrack2Voters*18)/100;
        }

        returnData = string(abi.encodePacked(returnData, 
            "Amount will be given to each voter:", uint2str(amountGivenToEachWinnerVoter/1000000000000000000), "\n",
            "Amount will be given to Winner Track Creator:", uint2str(amountToGivenCreator/1000000000000000000), "\n",
            "Transferring reward to Track Creator\n",
            "Winner balance before: ", uint2str(battle.creatorTrack2.balance/1000000000000000000), "\n"
        ));

        uint256 x = battle.creatorTrack2.balance;
        payable(battle.creatorTrack2).transfer(amountToGivenCreator);
        
        returnData = string(abi.encodePacked(returnData, 
            "Track 2 Creator receives : ", uint2str(amountToGivenCreator/1000000000000000000), "\n",
            "Winner balance after: ", uint2str(battle.creatorTrack2.balance/1000000000000000000), "\n"
        ));

        uint256 difference = (battle.creatorTrack2.balance-x)/1000000000000000000;
        returnData = string(abi.encodePacked(returnData, "Difference in winner's balance: ", uint2str(difference), "\n"));

        if(difference == 0) {
            returnData = string(abi.encodePacked(returnData, 
                "Money is reverted back to the contract\n",
                "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
            ));
        }

        returnData = string(abi.encodePacked(returnData, 
            "Transferring reward to winner voters\n",
            "battle.votesTrack2: ", uint2str(battle.votesTrack2), "\n"
        ));
        
        require(battle.votersOfTrack2.length >= battle.votesTrack2, "Voters array length mismatch");
        for(uint i=0; i<battle.votesTrack2; i++) {
            require(battle.votersOfTrack2[i] != address(0), "Invalid voter address");
            returnData = string(abi.encodePacked(returnData, 
                "Winner Voter Number:", uint2str(i), "Winner Voter balance before: ", uint2str(battle.votersOfTrack2[i].balance/1000000000000000000), "\n"
            ));
            
            uint256 y = battle.votersOfTrack2[i].balance;
            payable(battle.votersOfTrack2[i]).transfer(amountGivenToEachWinnerVoter);
            
            returnData = string(abi.encodePacked(returnData, 
                "Amount recieved by the voter No:", uint2str(i), " : ", uint2str(amountGivenToEachWinnerVoter/1000000000000000000), "\n",
                "Winner Voter Number:", uint2str(i), "Winner Voter balance after: ", uint2str(battle.votersOfTrack2[i].balance/1000000000000000000), "\n"
            ));
            
            difference = (battle.votersOfTrack2[i].balance-y)/1000000000000000000;
            returnData = string(abi.encodePacked(returnData, "Difference in voter's balance: ", uint2str(difference), "\n"));
            
            if(difference == 0) {
                returnData = string(abi.encodePacked(returnData, 
                    "Money is reverted back to the contract\n",
                    "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
                ));
            }
        }

        battle.isActive = false;
        emit BattleEnded(battleId, battle.creatorTrack2);
        emit BattleConcluded(battleId, "Track 2 Won", battle.creatorTrack2, battle.voters, true);

        returnData = string(abi.encodePacked(returnData, 
            "Remaining Balance Left on contract:", uint2str(address(this).balance/1000000000000000000), "\n"
        ));
        
        difference = (w-address(this).balance)/1000000000000000000;
        returnData = string(abi.encodePacked(returnData, "Difference in contract Balance :", uint2str(difference), "\n"));
        
        if(difference == 0) {
            returnData = string(abi.encodePacked(returnData, 
                "Money is reverted back to the contract\n",
                "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
            ));
        }
        return (2, returnData);
    }
    else {

    returnData = string(abi.encodePacked(returnData, 
        "There is a Tie\n",
        "Track 1 & 2 are the winners\n"
    ));

    uint256 amountGivenToEachWinnerVoter = ((battle.amountGivenByTrack1Voters + battle.amountGivenByTrack2Voters)*(800000000000000000))/SCALE; // 80%
    if( battle.votesTrack1+battle.votesTrack2==0 ){
        returnData = string(abi.encodePacked(returnData, 
            "There are no voters\n",
            "Sending 50% money of Starting Battle Fees Back to the person wallet who started the battle\n",
            "Battle Creator address:", addressToString(battle.battleCreator), "\n",
            "Intial Balance:", uint2str(battle.battleCreator.balance/1000000000000000000), "\n"
        ));

        uint256 amountToBeSent = (battle.startingFees*5)/10;
        uint temp = battle.battleCreator.balance;
        payable(battle.battleCreator).transfer(amountToBeSent);
        
        returnData = string(abi.encodePacked(returnData, 
            "After Getting Payment Balance:", uint2str(battle.battleCreator.balance/1000000000000000000), "\n"
        ));

        uint256 difference1 = (battle.battleCreator.balance-temp)/1000000000000000000;
        returnData = string(abi.encodePacked(returnData, "Difference in Track Creator 1's balance: ", uint2str(difference1), "\n"));

        if(difference1==0){
            returnData = string(abi.encodePacked(returnData, 
                "Money is reverted back to the contract\n",
                "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
            ));
        }

        returnData = string(abi.encodePacked(returnData, 
            "Sending 20% money of Starting Battle Fees to Creator of Track 1:\n",
            "Creator of Track 1 address:", addressToString(battle.creatorTrack1), "\n",
            "Intial Balance:", uint2str(battle.creatorTrack1.balance/1000000000000000000), "\n"
        ));

        amountToBeSent = (battle.startingFees*2)/10;
        temp = battle.creatorTrack1.balance;
        payable(battle.creatorTrack1).transfer(amountToBeSent);
        
        returnData = string(abi.encodePacked(returnData, 
            "After Getting Payment Balance:", uint2str(battle.creatorTrack1.balance/1000000000000000000), "\n"
        ));

        difference1 = (battle.creatorTrack1.balance-temp)/1000000000000000000;
        returnData = string(abi.encodePacked(returnData, "Difference in Track Creator 1's balance: ", uint2str(difference1), "\n"));

        if(difference1==0){
            returnData = string(abi.encodePacked(returnData, 
                "Money is reverted back to the contract\n",
                "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
            ));
        }

        returnData = string(abi.encodePacked(returnData, 
            "Sending 20% money of Starting Battle Fees to Creator of Track 2:\n",
            "Creator of Track 2 address:", addressToString(battle.creatorTrack2), "\n",
            "Intial Balance:", uint2str(battle.creatorTrack2.balance/1000000000000000000), "\n"
        ));

        amountToBeSent = (battle.startingFees*2)/10;
        temp = battle.creatorTrack2.balance;
        payable(battle.creatorTrack2).transfer(amountToBeSent);
        
        returnData = string(abi.encodePacked(returnData, 
            "After Getting Payment Balance:", uint2str(battle.creatorTrack2.balance/1000000000000000000), "\n"
        ));

        difference1 = (battle.creatorTrack2.balance-temp)/1000000000000000000;
        returnData = string(abi.encodePacked(returnData, "Difference in Track Creator 1's balance: ", uint2str(difference1), "\n"));

        if(difference1==0){
            returnData = string(abi.encodePacked(returnData, 
                "Money is reverted back to the contract\n",
                "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
            ));
        }

        returnData = string(abi.encodePacked(returnData, 
            "10% of battle fees remains back in the contract as contract fund\n",
            "10% of battle fees is:", uint2str(((battle.startingFees*1)/10)/1000000000000000000), "\n"
        ));

        battles[battleId].isActive = false;
        emit BattleEnded(battleId, battle.creatorTrack1);
        emit BattleEnded(battleId, battle.creatorTrack2);
        emit BattleConcluded(battleId, "Track 1 Won", battle.creatorTrack1, battle.votersOfTrack1, true);
        emit BattleConcluded(battleId, "Track 2 Won", battle.creatorTrack1, battle.votersOfTrack2, true);

        returnData = string(abi.encodePacked(returnData, 
            "Remaining Balance Left on contract:", uint2str(address(this).balance/1000000000000000000), "\n",
            "Difference in contract Balance :", uint2str((w-address(this).balance)/1000000000000000000), "\n"
        ));

        return (0, returnData);
    }

    amountGivenToEachWinnerVoter /= (battle.votesTrack1+battle.votesTrack2);
    uint256 amountToGivenCreator = (battle.amountGivenByTrack1Voters + battle.amountGivenByTrack2Voters)/(10);
    amountToGivenCreator/=2;

    returnData = string(abi.encodePacked(returnData, 
        "Transferring reward to Track Creator 1\n",
        "Track Creator 1's Balance before: ", uint2str(battle.creatorTrack1.balance/1000000000000000000), "\n"
    ));

    uint256 x = battle.creatorTrack1.balance;
    payable(battle.creatorTrack1).transfer(amountToGivenCreator);
    
    returnData = string(abi.encodePacked(returnData, 
        "Track 1 Creator receives : ", uint2str(amountToGivenCreator/1000000000000000000), "\n",
        "Track Creator 1's Balance after: ", uint2str(battle.creatorTrack1.balance/1000000000000000000), "\n"
    ));

    uint256 difference = (battle.creatorTrack1.balance-x)/1000000000000000000;
    returnData = string(abi.encodePacked(returnData, "Difference in Track Creator 1's balance: ", uint2str(difference), "\n"));

    if(difference==0){
        returnData = string(abi.encodePacked(returnData, 
            "Money is reverted back to the contract\n",
            "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
        ));
    }

    returnData = string(abi.encodePacked(returnData, 
        "Transferring reward to Track Creator 2\n",
        "Track Creator 2's Balance before: ", uint2str(battle.creatorTrack2.balance/1000000000000000000), "\n"
    ));

    x = battle.creatorTrack2.balance;
    payable(battle.creatorTrack2).transfer(amountToGivenCreator);
    
    returnData = string(abi.encodePacked(returnData, 
        "Track 2 Creator receives : ", uint2str(amountToGivenCreator/1000000000000000000), "\n",
        "Track Creator 2's Balance after: ", uint2str(battle.creatorTrack2.balance/1000000000000000000), "\n"
    ));

    difference = (battle.creatorTrack2.balance-x)/1000000000000000000;
    returnData = string(abi.encodePacked(returnData, "Difference in Track Creator 2's balance: ", uint2str(difference), "\n"));

    if(difference==0){
        returnData = string(abi.encodePacked(returnData, 
            "Money is reverted back to the contract\n",
            "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
        ));
    }

    returnData = string(abi.encodePacked(returnData, 
        "Transferring reward to winner voters\n",
        "battle.votesTrack1: ", uint2str(battle.votesTrack1), "\n"
    ));

    require(battle.votersOfTrack1.length >= battle.votesTrack1, "Voters array length mismatch");
    for(uint i=0; i<battle.votesTrack1; i++) {
        require(battle.votersOfTrack1[i] != address(0), "Invalid voter address");
        returnData = string(abi.encodePacked(returnData, 
            "Winner Voter Number:", uint2str(i), "Winner Voter balance before: ", uint2str(battle.votersOfTrack1[i].balance/1000000000000000000), "\n"
        ));

        uint256 y = battle.votersOfTrack1[i].balance;
        payable(battle.votersOfTrack1[i]).transfer(amountGivenToEachWinnerVoter);
        
        returnData = string(abi.encodePacked(returnData, 
            "Amount recieved by the voter No:", uint2str(i), " : ", uint2str(amountGivenToEachWinnerVoter/1000000000000000000), "\n",
            "Winner Voter Number:", uint2str(i), "Winner Voter balance after: ", uint2str(battle.votersOfTrack1[i].balance/1000000000000000000), "\n"
        ));

        difference = (battle.votersOfTrack1[i].balance-y)/1000000000000000000;
        returnData = string(abi.encodePacked(returnData, "Difference in voter's balance: ", uint2str(difference), "\n"));

        if(difference==0){
            returnData = string(abi.encodePacked(returnData, 
                "Money is reverted back to the contract\n",
                "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
            ));
        }
    }

    require(battle.votersOfTrack2.length >= battle.votesTrack2, "Voters array length mismatch");
    for(uint i=0; i<battle.votesTrack2; i++) {
        require(battle.votersOfTrack2[i] != address(0), "Invalid voter address");
        returnData = string(abi.encodePacked(returnData, 
            "Winner Voter Number:", uint2str(i), "Winner Voter balance before: ", uint2str(battle.votersOfTrack2[i].balance/1000000000000000000), "\n"
        ));

        uint256 y = battle.votersOfTrack2[i].balance;
        payable(battle.votersOfTrack2[i]).transfer(amountGivenToEachWinnerVoter);
        
        returnData = string(abi.encodePacked(returnData, 
            "Amount recieved by the voter No:", uint2str(i), " : ", uint2str(amountGivenToEachWinnerVoter/1000000000000000000), "\n",
            "Winner Voter Number:", uint2str(i), "Winner Voter balance after: ", uint2str(battle.votersOfTrack2[i].balance/1000000000000000000), "\n"
        ));

        difference = (battle.votersOfTrack2[i].balance-y)/1000000000000000000;
        returnData = string(abi.encodePacked(returnData, "Difference in voter's balance: ", uint2str(difference), "\n"));

        if(difference==0){
            returnData = string(abi.encodePacked(returnData, 
                "Money is reverted back to the contract\n",
                "One Reason is that wallet contains maximum allowed amount , which 10,000 ETH\n"
            ));
        }
    }

    battle.isActive = false;
    emit BattleEnded(battleId, battle.creatorTrack1);
    emit BattleEnded(battleId, battle.creatorTrack2);
    emit BattleConcluded(battleId, "Track 1 Won", battle.creatorTrack1, battle.votersOfTrack1, true);
    emit BattleConcluded(battleId, "Track 2 Won", battle.creatorTrack1, battle.votersOfTrack2, true);

    returnData = string(abi.encodePacked(returnData, 
        "Remaining Balance Left on contract:", uint2str(address(this).balance/1000000000000000000), "\n",
        "Difference in contract Balance :", uint2str((w-address(this).balance)/1000000000000000000), "\n"
    ));

    return (0, returnData);}
}



function getBattleVotes(uint256 battleId) public view returns (uint256 track1Votes, uint256 track2Votes) {
        require(battleId > 0 && battleId <= battleCount, "Battle does not exist");
        Battle storage battle = battles[battleId];
        return (battle.votesTrack1, battle.votesTrack2);
    }

function getBattleDetails(uint256 battleId) public view returns (
        string memory track1, 
        string memory track2, 
        uint256 votesTrack1, 
        uint256 votesTrack2,
        uint256 timestamp,
        bool isActive,
        address winner
    ) {
        require(battleId > 0 && battleId <= battleCount, "Battle does not exist");
        Battle storage battle = battles[battleId];
        return (
            battle.track1, 
            battle.track2, 
            battle.votesTrack1, 
            battle.votesTrack2,
            battle.timestamp,
            battle.isActive,
            battle.winner
        );
    }

function getTotalVoters(uint256 battleId) public view returns (uint256) {
        require(battleId > 0 && battleId <= battleCount, "Battle does not exist");
        return battles[battleId].voters.length;
    }

function getBalance() public view returns (uint256) {
    console.log("address(this).balance: ",(address(this).balance)/1000000000000000000);
    return (address(this).balance/1000000000000000000);
}


// Solidity smart contract function
function transferFundsFromContractToOwner(
    uint256 amount,
    address addressToSendMoney
) public onlyOwnerOrCreator returns (bool) {
    // Log the actual caller's address
    console.log("Transaction sender (msg.sender):", msg.sender);
    
    // Check contract balance
    require(address(this).balance >= amount, "Insufficient contract balance");
    
    // Store initial balances for logging
    uint256 initialContractBalance = address(this).balance;
    uint256 initialRecipientBalance = addressToSendMoney.balance;
    
    // Create payable address for recipient
    address payable recipient = payable(addressToSendMoney);
    
    // Transfer ETH using call
    (bool success, ) = recipient.call{value: amount}("");
    require(success, "Transfer failed");
    
    // Verify the transfer
    require(
        address(this).balance == initialContractBalance - amount,
        "Transfer amount mismatch"
    );
    require(
        addressToSendMoney.balance == initialRecipientBalance + amount,
        "Recipient balance mismatch"
    );
    
    // Log the transfer details with both addresses
    emit FundsTransferredToOwner(amount, recipient);
    
    return true;
}

function toggleOracleTime(bool _useOracle) public onlyOwnerOrCreator {
        useOracleTime = _useOracle;
    }

function getSpecificTrackVoters(uint trackNumber, uint battleId) public view returns (address[] memory winnerVoters) {
    require(battleId > 0 && battleId <= battleCount, "Battle does not exist");
    require(trackNumber == 1 || trackNumber == 2, "Invalid trackNumber");

    if (trackNumber == 1) {
        return battles[battleId].votersOfTrack1;
    } else {
        return battles[battleId].votersOfTrack2;
    }
}


function votersList(uint256 battleId) public view returns (address[] memory _votersList) {
    require(battleId > 0 && battleId <= battleCount, "Battle does not exist");
    console.log("Voters list:");
    for(uint16 i=0;i<battles[battleId].voters.length;i++){
        console.log(battles[battleId].voters[i]);
    }
    return battles[battleId].voters;
}


    function battleVoters(uint256 battleId, address userAddress) public view returns (bool) {
    Battle storage battle = battles[battleId];
    return battle.hasVoted[userAddress];
}


    // To allow contract to receive Ether
    receive() external payable {}
}
