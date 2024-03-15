//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import '../base/CustomChanIbcApp.sol';

/** 
 * @title XBallot
 * @dev Implements voting process along with vote delegation, 
 * and ability to send cross-chain instruction to mint NFT on counterparty
 */
contract XBallot is CustomChanIbcApp {
    enum IbcPacketStatus {UNSENT, SENT, ACKED, TIMEOUT}

    struct Voter {
        uint weight; // weight is accumulated by delegation
        bool voted;  // if true, that person already voted;    
        address delegate; // person delegated to
        uint vote;   // index of the voted proposal
        // additional
        IbcPacketStatus ibcPacketStatus;
        uint[] voteNFTIds;
    }

    struct Proposal {
        // If you can limit the length to a certain number of bytes, 
        // always use one of bytes1 to bytes32 because they are much cheaper
        bytes32 name;   // short name (up to 32 bytes)
        uint voteCount; // number of accumulated votes
    }

    address public chairperson;

    mapping(address => Voter) public voters;

    Proposal[] public proposals;

    modifier onlyChairperson() {
        require(msg.sender == chairperson, "Not chairperson.");
        _;
    }

    event Voted(address indexed voter, uint proposal);  // Exposing the vote information for debugging; hide in production if you want private voting
    event SendVoteInfo(bytes32 channelId, address indexed voter, address indexed recipient, uint proposal);
    event AckNFTMint(bytes32 channelId, uint sequence, address indexed voter, uint voteNFTid);

    /** 
     * @dev Create a new ballot to choose one of 'proposalNames' and make it IBC enabled to send proof of Vote to counterparty
     * @param _dispatcher vIBC dispatcher contract
     * @param proposalNames names of proposals
     */
    constructor( IbcDispatcher _dispatcher, bytes32[] memory proposalNames) CustomChanIbcApp(_dispatcher) {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        for (uint i = 0; i < proposalNames.length; i++) {
            // 'Proposal({...})' creates a temporary
            // Proposal object and 'proposals.push(...)'
            // appends it to the end of 'proposals'.
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }

    /** 
     * @dev Give 'voter' the right to vote on this ballot. May only be called by 'chairperson'.
     * @param voter address of voter
     */
    function giveRightToVote(address voter) public {
        require(
            msg.sender == chairperson,
            "Only chairperson can give right to vote."
        );
        require(
            !voters[voter].voted,
            "The voter already voted."
        );
        require(voters[voter].weight == 0);
        voters[voter].weight = 1;
    }

    /**
     * @dev Delegate your vote to the voter 'to'.
     * @param to address to which vote is delegated
     */
    function delegate(address to) public {
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "You already voted.");
        require(to != msg.sender, "Self-delegation is disallowed.");

        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;

            // We found a loop in the delegation, not allowed.
            require(to != msg.sender, "Found loop in delegation.");
        }
        sender.voted = true;
        sender.delegate = to;
        Voter storage delegate_ = voters[to];
        if (delegate_.voted) {
            // If the delegate already voted,
            // directly add to the number of votes
            proposals[delegate_.vote].voteCount += sender.weight;
        } else {
            // If the delegate did not vote yet,
            // add to her weight.
            delegate_.weight += sender.weight;
        }
    }

    /**
     * @dev Give your vote (including votes delegated to you) to proposal 'proposals[proposal].name'.
     * @param proposal index of proposal in the proposals array
     */
    function vote(uint proposal) public {
        Voter storage sender = voters[msg.sender];
        // FOR TESTING ONLY
        // ----------------
        sender.weight = 1;
        sender.ibcPacketStatus = IbcPacketStatus.UNSENT;
        require(sender.weight != 0, "Has no right to vote");
        // require(!sender.voted, "Already voted.");
        // ----------------
        sender.voted = true;
        sender.vote = proposal;

        // If 'proposal' is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        proposals[proposal].voteCount += sender.weight;

        emit Voted(msg.sender, proposal);
    }


    /** 
     * @dev Computes the winning proposal taking all previous votes into account.
     * @return winningProposal_ index of winning proposal in the proposals array
     */
    function winningProposal() public view
            returns (uint winningProposal_)
    {
        uint winningVoteCount = 0;
        for (uint p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    /** 
     * @dev Calls winningProposal() function to get the index of the winner contained in the proposals array and then
     * @return winnerName_ the name of the winner
     */
    function winnerName() public view
            returns (bytes32 winnerName_)
    {
        winnerName_ = proposals[winningProposal()].name;
    }

    // IBC methods

    /**
     * @dev Sends a packet with a greeting message over a specified channel.
     * @param channelId The ID of the channel to send the packet to.
     * @param timeoutSeconds The timeout in seconds (relative).
     * @param voterAddress the address of the voter
     * @param recipient the address on the destination (Base) that will have NFT minted
     */
    function sendPacket(
        bytes32 channelId,
        uint64 timeoutSeconds,
        address voterAddress,
        address recipient
    ) external {
        Voter storage voter = voters[voterAddress];
        require(voter.ibcPacketStatus == IbcPacketStatus.UNSENT || voter.ibcPacketStatus == IbcPacketStatus.TIMEOUT, "An IBC packet relating to his vote has already been sent. Wait for acknowledgement.");

        uint proposal = voter.vote;
        bytes memory payload = abi.encode(voterAddress, recipient);

        uint64 timeoutTimestamp = uint64((block.timestamp + timeoutSeconds) * 1000000000);

        dispatcher.sendPacket(channelId, payload, timeoutTimestamp);
        voter.ibcPacketStatus = IbcPacketStatus.SENT;

        emit SendVoteInfo(channelId, voterAddress, recipient, proposal);
    }

    function onRecvPacket(IbcPacket memory) external override view onlyIbcDispatcher returns (AckPacket memory ackPacket) {
        require(false, "This function should not be called");

        return AckPacket(true, abi.encode("Error: This function should not be called"));
    }

    function onAcknowledgementPacket(IbcPacket calldata packet, AckPacket calldata ack) external override onlyIbcDispatcher {
        ackPackets.push(ack);
        
        // decode the ack data, find the address of the voter the packet belongs to and set ibcNFTMinted true
        (address voterAddress, uint256 voteNFTid) = abi.decode(ack.data, (address, uint256));
        voters[voterAddress].ibcPacketStatus = IbcPacketStatus.ACKED;
        voters[voterAddress].voteNFTIds.push(voteNFTid);

        emit AckNFTMint(packet.src.channelId, packet.sequence, voterAddress, voteNFTid);
    }

    function onTimeoutPacket(IbcPacket calldata packet) external override onlyIbcDispatcher {
        timeoutPackets.push(packet);
        // do logic
    }
}