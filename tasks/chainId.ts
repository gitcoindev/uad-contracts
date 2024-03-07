import { task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

task("chainId", "Prints the current chain ID").setAction(
  async (_taskArgs, { ethers }) => {
    await ethers.provider.getNetwork().then((net) => {
      console.log(`Current chain ID: ${net.chainId}`);
    });
  }
);
