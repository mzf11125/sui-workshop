import { getFullnodeUrl } from "@mysten/sui/client";
import { createNetworkConfig } from "@mysten/dapp-kit";

const { networkConfig, useNetworkVariable, useNetworkVariables } =
  createNetworkConfig({
    devnet: {
      url: getFullnodeUrl("devnet"),
      variables: {
        // TODO: Update with your deployed contract address
        simpleArtNFT: "0x0",
        collectionId: "0x0",
      },
    },
    testnet: {
      url: getFullnodeUrl("testnet"),
      variables: {
        // replace with your deployed contract address
        simpleArtNFT: "0xb91d818720877e690834139e58b0ebed7d63e4ab8b5c263fe1cefdcfea48d1a9",

        // replace with your collection id
        collectionId: "0x2e5e1fa6234721bd1ad7cc789429132cf19d5e202e917af4ca88de61af162ee4",
      },
    },
    mainnet: {
      url: getFullnodeUrl("mainnet"),
      variables: {
        // TODO: Update with your deployed contract address
        simpleArtNFT: "0x0",
        collectionId: "0x0",
      },
    },
  });

export { useNetworkVariable, useNetworkVariables, networkConfig };