import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Fixture } from "ethereum-waffle";

import type { Greeter } from "../src/types/Greeter";
import { NFTMarket } from "../src/types/NFTMarket";
import { NFTWithRoyalties } from "../src/types/NFTWithRoyalties";

declare module "mocha" {
  export interface Context {
    // marketPlace: NFTMarket;
    // nftRoyalty: NFTWithRoyalties;
    greeter: Greeter;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
    // owner: SignerWithAddress;
    // buyer: SignerWithAddress;
    // royaltyFund: SignerWithAddress;
  }
}

export interface Signers {
  admin: SignerWithAddress;
}
