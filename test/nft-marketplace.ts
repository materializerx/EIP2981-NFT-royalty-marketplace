import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { NFTWithRoyalties } from "../src/types/NFTWithRoyalties";
import type { NFTMarketplace } from "../src/types/NFTMarketplace";
import { expect } from "chai";

const _INTERFACE_ID_ERC165 = "0x01ffc9a7";
const _INTERFACE_ID_ROYALTIES_EIP2981 = "0x2a55205a";
const _INTERFACE_ID_ERC721 = "0x80ac58cd";

describe.only("NFT with royalty", function () {
  let marketplace: NFTMarketplace;
  let nftRoyalty: NFTWithRoyalties;
  let marketplaceOwner: SignerWithAddress;
  let nftRoyaltyOwner: SignerWithAddress;
  let seller: SignerWithAddress;
  let buyer: SignerWithAddress;
  let royaltyFund: SignerWithAddress;
  let listingPrice: string;
  let tokenId: number;
  before(async function () {
    [marketplaceOwner, nftRoyaltyOwner, seller, buyer, royaltyFund] = await ethers.getSigners();
  });

  describe.only("royalty nft behaviour", function () {
    before(async () => {
      const marketPlaceArfifact: Artifact = await artifacts.readArtifact("NFTMarketplace");
      const nftRoyaltyArtifact: Artifact = await artifacts.readArtifact("NFTWithRoyalties");
      marketplace = <NFTMarketplace>await waffle.deployContract(marketplaceOwner, marketPlaceArfifact, []);
      nftRoyalty = <NFTWithRoyalties>(
        await waffle.deployContract(nftRoyaltyOwner, nftRoyaltyArtifact, [marketplace.address])
      );

      // seller create a token
      const ntfRoyalty = nftRoyalty.connect(nftRoyaltyOwner);
      const tokenURI = "nft.royalty";
      // set royalty to 30%
      const royaltyAmount = 3000;
      const tx1 = await ntfRoyalty.connect(seller).createToken(tokenURI, royaltyFund.address, royaltyAmount);
      // created tokenId is 1
      tokenId = 1;
      // expect the event `TokenCreated(1)` be emitted
      expect(tx1).to.emit(ntfRoyalty, "TokenCreated").withArgs(tokenId);
    });

    it("creates a market item", async () => {
      const price = ethers.utils.parseUnits("1", "ether");
      const listingPrice = (await marketplace.getListingPrice()).toString();
      // seller creates/announces an item to the marketplace
      const tx2 = await marketplace
        .connect(seller)
        .createMarketItem(nftRoyalty.address, tokenId, price, { value: listingPrice });
      // check the event
      expect(tx2).to.emit(marketplace, "MarketItemCreated");
      // check if the ownership has been transfer from the seller to the marketplace
      expect(await nftRoyalty.connect(nftRoyaltyOwner).ownerOf(tokenId)).to.equal(marketplace.address);
    });

    it("sells a market item", async () => {
      // token price
      const price = ethers.utils.parseUnits("1", "ether");
      const tx = await marketplace.connect(buyer).createMarketSale(nftRoyalty.address, tokenId, { value: price });
      // check for the event
      expect(tx).to.emit(marketplace, "MarketItemSold");
      // check if ownership has been transferred from marketplace to buyer
      expect(await nftRoyalty.ownerOf(tokenId)).to.equal(buyer.address);
      // check if the royalty has been transferred to the royalty recipient address
      const initialBalance = ethers.utils.parseUnits("10000", "ether");
      expect(await royaltyFund.getBalance()).to.gt(initialBalance);
    });
  });
});
