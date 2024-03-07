import { task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

task("blockNumber", "Prints the current block number").setAction(
  async (_taskArgs, { ethers }) => {
    await ethers.provider.getBlockNumber().then((blockNumber) => {
      console.log(`Current block number: ${blockNumber}`);
    });
  }
);
