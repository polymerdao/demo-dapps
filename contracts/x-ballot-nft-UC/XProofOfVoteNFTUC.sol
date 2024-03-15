//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


import '../base/UniversalChanIbcApp.sol';

contract XProofOfVoteNFTUC is ERC721, UniversalChanIbcApp {
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenId;

    string baseURI;
    string private suffix = "/500/500";

    event MintedOnRecv(address srcPortAddr, address indexed recipient, uint256 voteNFTId);

    constructor(address _middleware, string memory _baseURI) 
        ERC721("UniversalProofOfVoteNFT", "PolyVoteUniversal")
        UniversalChanIbcApp(_middleware) {
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

    function updateTokenURI(string memory _newBaseURI) public {
        baseURI = _newBaseURI;
    }

    // IBC methods

    function onRecvUniversalPacket(
        bytes32 channelId,
        UniversalPacket calldata packet
    ) external override onlyIbcMw returns (AckPacket memory ackPacket) {
        recvedPackets.push(UcPacketWithChannel(channelId, packet));

        // Decode the packet data
        (address decodedVoter, address decodedRecipient) = abi.decode(packet.appData, (address, address));

        // Mint the NFT
        uint256 voteNFTid = mint(decodedRecipient);
        emit MintedOnRecv(IbcUtils.toAddress(packet.srcPortAddr), decodedRecipient, voteNFTid);

        // Encode the ack data
        bytes memory ackData = abi.encode(decodedVoter, voteNFTid);

        return AckPacket(true, ackData);
    }

    function onUniversalAcknowledgement(
            bytes32,
            UniversalPacket memory,
            AckPacket calldata
    ) external override view onlyIbcMw {
        require(false, "This function should not be called");
    }

    function onTimeoutUniversalPacket(
        bytes32, 
        UniversalPacket calldata
    ) external override view onlyIbcMw {
        require(false, "This function should not be called");
    }
}
