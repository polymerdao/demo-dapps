//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import '../base/CustomChanIbcApp.sol';

contract XProofOfVoteNFT is ERC721, CustomChanIbcApp {
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenId;

    string baseURI;
    string private suffix = "/500/500";

    event MintedOnRecv(bytes32 channelId, uint64 sequence, address indexed recipient, uint256 voteNFTId);

    constructor(IbcDispatcher _dispatcher, string memory _baseURI) 
    CustomChanIbcApp(_dispatcher) ERC721("ProofOfVoteNFT", "PolyVote"){
        baseURI = _baseURI;
    }

    function mint(address recipient)
        internal
        returns (uint256)
    {
        currentTokenId.increment();
        uint256 tokenId = currentTokenId.current();
        _safeMint(recipient, tokenId);
        return tokenId;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return string(abi.encodePacked(baseURI, Strings.toString(tokenId), suffix));
    }

    function updateBaseURI(string memory _newBaseURI) public {
        baseURI = _newBaseURI;
    }

    // IBC methods

    // This contract only receives packets from the IBC dispatcher

    function onRecvPacket(IbcPacket memory packet) external override onlyIbcDispatcher returns (AckPacket memory ackPacket) {
        recvedPackets.push(packet);
        
        // Decode the packet data
        (address decodedVoter, address decodedRecipient) = abi.decode(packet.data, (address, address));

        // Mint the NFT
        uint256 voteNFTid = mint(decodedRecipient);
        emit MintedOnRecv(packet.dest.channelId, packet.sequence, decodedRecipient, voteNFTid);

        // Encode the ack data
        bytes memory ackData = abi.encode(decodedVoter, voteNFTid);

        return AckPacket(true, ackData);
    }

    function onAcknowledgementPacket(IbcPacket calldata, AckPacket calldata) external view override onlyIbcDispatcher {
        require(false, "This contract should never receive an acknowledgement packet");
    }

    function onTimeoutPacket(IbcPacket calldata) external view override onlyIbcDispatcher {
        require(false, "This contract should never receive a timeout packet");
    }
}