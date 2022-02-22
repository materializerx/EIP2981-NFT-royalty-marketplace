// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./royalty/ERC2981PerTokenRoyalties.sol";

import "hardhat/console.sol";

contract NFTWithRoyalties is ERC721URIStorage, ERC2981PerTokenRoyalties {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address public contractAddress;

    event TokenCreated(uint256 tokenId);

    // TODO: can be made to support multi marketplace
    constructor(address marketplaceAddress) ERC721("MetaRoyalty", "ROYALTY") {
        contractAddress = marketplaceAddress;
    }

    // TODO: add multiple marketplaces
    // function addMarketPlace(address marketplaceAddr) {
    //     marketplaces.push(marketplaceAddr)
    // }

    function createToken(
        string memory tokenURI,
        address royaltyRecipient,
        uint256 royaltyAmount
    ) public returns (uint256) {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        _safeMint(msg.sender, tokenId, "");
        _setTokenURI(tokenId, tokenURI);

        if (royaltyAmount > 0) {
            _setTokenRoyalty(tokenId, royaltyRecipient, royaltyAmount);
        }

        // for loop for all marketplaces in marketplace[] array
        setApprovalForAll(contractAddress, true);

        emit TokenCreated(tokenId);

        return tokenId;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981Base) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
