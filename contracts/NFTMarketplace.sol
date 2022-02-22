// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
// import "./royalty/ERC2981Base.sol";
import "./royalty/ERC2981PerTokenRoyalties.sol";

contract NFTMarketplace is ReentrancyGuard {
    using Counters for Counters.Counter;
    using ERC165Checker for address;

    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    address payable public owner;
    uint256 public listingPrice = 0.025 ether;
    bytes4 public constant _INTERFACE_ID_ROYALTIES_EIP2981 = type(IERC2981Royalties).interfaceId;

    constructor() {
        owner = payable(msg.sender);
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        uint256 royaltyAmount;
        address royaltyRecipient;
        bool sold;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        uint256 royaltyAmount,
        address royaltyRecipient,
        bool sold
    );

    event MarketItemSold(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        uint256 royaltyAmount,
        address royaltyRecipient
    );

    /* Returns the listing price of the contract */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    /* Places an item for sale on the marketplace */
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(msg.value == listingPrice, "Price must be equal to listing price");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        address royaltyRecipient;
        uint256 royaltyAmount = 0;

        // check if it supports EIP2981 Royalty standard
        if (nftContract.supportsInterface(_INTERFACE_ID_ROYALTIES_EIP2981)) {
            (royaltyRecipient, royaltyAmount) = ERC2981PerTokenRoyalties(nftContract).royaltyInfo(tokenId, price);
        }
        // the reason to include royalty information into the contract MarketItem is that
        // we need to show this information in front-end so the user can know associated royalty info
        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            royaltyAmount,
            royaltyRecipient,
            false
        );

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            royaltyAmount,
            royaltyRecipient,
            false
        );
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(address nftContract, uint256 itemId) public payable nonReentrant {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");

        // if no royalty to be paid, initially it is set to zero
        uint256 royaltyAmount = 0;
        address royaltyRecipient = address(0);
        // check if the nft contract has support for EIP 2981 Royalty Standard
        // this means the royalty has to be paid
        if (nftContract.supportsInterface(_INTERFACE_ID_ROYALTIES_EIP2981)) {
            (royaltyRecipient, royaltyAmount) = ERC2981PerTokenRoyalties(nftContract).royaltyInfo(tokenId, price);
        }

        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = true;
        // transfer the royalty to the royalty recipient
        payable(royaltyRecipient).transfer(royaltyAmount);
        // transfer the (item price - royalty amount) to the seller
        idToMarketItem[itemId].seller.transfer(msg.value - royaltyAmount);

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        _itemsSold.increment();
        payable(owner).transfer(listingPrice);

        emit MarketItemSold(
            itemId,
            nftContract,
            tokenId,
            // TODO: do I have to create local memory variable to store Storage variable first?
            idToMarketItem[itemId].seller,
            idToMarketItem[itemId].owner,
            price,
            royaltyAmount,
            royaltyRecipient
        );
    }

    /* Returns all unsold market items */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns onlyl items that a user has purchased */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items a user has created */
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
