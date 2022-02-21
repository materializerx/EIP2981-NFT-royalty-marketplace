// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
// import "./royalty/ERC2981Base.sol";
import "./royalty/ERC2981PerTokenRoyalties.sol";

import "hardhat/console.sol";

contract NFTMarket is ReentrancyGuard {
    using Counters for Counters.Counter;
    using ERC165Checker for address;

    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    address payable owner;
    uint256 listingPrice = 0.025 ether;
    bytes4 InterfaceId_IERC2981Royalties = type(IERC2981Royalties).interfaceId;

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

        // check if it supports royalty feature
        if (nftContract.supportsInterface(InterfaceId_IERC2981Royalties)) {
            (royaltyRecipient, royaltyAmount) = ERC2981PerTokenRoyalties(nftContract).royaltyInfo(tokenId, price);
        }

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

    // function royaltyInfo(
    //   address nftContract,
    //   uint256 itemId
    //   ) public view returns (address recipient, uint256 royaltyAmount) {
    //   uint price = idToMarketItem[itemId].price;
    //   uint tokenId = idToMarketItem[itemId].tokenId;

    //   (recipient, royaltyAmount) = ERC2981PerTokenRoyalties(nftContract).royaltyInfo(tokenId, price);
    // }
    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(address nftContract, uint256 itemId) public payable nonReentrant {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        console.log("tokenId", tokenId);
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");

        // if no royalty to be paid, initially it is set to zero
        uint256 royaltyAmount = 0;
        // bytes4 InterfaceId_IERC2981Royalties = type(IERC2981Royalties).interfaceId;
        // check if the nft contract has support for EIP2981
        // this means the royalty has to be paid
        if (nftContract.supportsInterface(InterfaceId_IERC2981Royalties)) {
            console.log("inside");
            address recipient;

            (recipient, royaltyAmount) = ERC2981PerTokenRoyalties(nftContract).royaltyInfo(tokenId, price);
            console.log("recipient", recipient);
            console.log("amount", royaltyAmount);
            // pay the royalty
            // query the balance before
            uint256 balanceBefore = recipient.balance;
            console.log("treasury balance before", balanceBefore);

            payable(recipient).transfer(royaltyAmount);

            // query the balance after
            uint256 balanceAfter = recipient.balance;
            console.log("treasury balance after ", balanceAfter);

            console.log("diff", balanceAfter - balanceBefore);
        }
        // seller balance before payment
        uint256 sellerBalanceBefore = idToMarketItem[itemId].seller.balance;
        console.log("seller balance before", sellerBalanceBefore);
        idToMarketItem[itemId].seller.transfer(msg.value - royaltyAmount);
        // seller balance after payment
        uint256 sellerBalanceAfter = idToMarketItem[itemId].seller.balance;
        console.log("seller balance after ", sellerBalanceAfter);
        // seller balance diff
        console.log("seller balance diff", sellerBalanceAfter - sellerBalanceBefore);

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = true;
        _itemsSold.increment();
        payable(owner).transfer(listingPrice);
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
