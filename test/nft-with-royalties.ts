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
  let marketPlace: NFTMarketplace;
  let nftRoyalty: NFTWithRoyalties;
  let marketPlaceOwner: SignerWithAddress;
  let nftOwner: SignerWithAddress;
  let buyer: SignerWithAddress;
  let royaltyFund: SignerWithAddress;

  before(async function () {
    [marketPlaceOwner, nftOwner, buyer, royaltyFund] = await ethers.getSigners();
  });

  describe("royalty nft behaviour", function () {
    beforeEach(async function () {
      const marketPlaceArfifact: Artifact = await artifacts.readArtifact("NFTMarketplace");
      const nftRoyaltyArtifact: Artifact = await artifacts.readArtifact("NFTWithRoyalties");
      marketPlace = <NFTMarketplace>await waffle.deployContract(marketPlaceOwner, marketPlaceArfifact, []);
      nftRoyalty = <NFTWithRoyalties>(
        await waffle.deployContract(marketPlaceOwner, nftRoyaltyArtifact, [marketPlace.address])
      );
    });

    it("should return the listing price", async function () {
      const listingPrice = (await marketPlace.connect(marketPlaceOwner).getListingPrice()).toString();
      expect(listingPrice).to.equal(ethers.utils.parseEther("0.025"));
    });
    it("creates a token with royalty", async () => {
      const ntfRoyalty = nftRoyalty.connect(nftOwner);
      const tokenURI = "nft.royalty";
      // set royalty to 30%
      const royaltyAmount = 3000;
      const tx = await ntfRoyalty.createToken(tokenURI, royaltyFund.address, royaltyAmount);
      // expect the event `TokenCreated(1)` be emitted
      expect(tx).to.emit(ntfRoyalty, "TokenCreated").withArgs(1);

      const tokenId = 1;
      const price = ethers.utils.parseEther("1");
      // query the royalty amount for the price of 1 ETH
      const [royaltyRecipient, amount] = await ntfRoyalty.royaltyInfo(tokenId, price);
      expect(royaltyRecipient).to.equal(royaltyFund.address);
      expect(amount).to.equal(ethers.utils.parseEther("0.3"));
    });

    it("has all the right interfaces", async function () {
      expect(await nftRoyalty.supportsInterface(_INTERFACE_ID_ERC165), "Error Royalties 165").to.be.true;

      expect(await nftRoyalty.supportsInterface(_INTERFACE_ID_ROYALTIES_EIP2981), "Error Royalties 2981").to.be.true;

      expect(await nftRoyalty.supportsInterface(_INTERFACE_ID_ERC721), "Error Royalties 721").to.be.true;
    });
  });
});
