import fs from "fs";
import path from "path";
import { task, types } from "hardhat/config";
import fetch from "node-fetch";
import * as ethers from "ethers";
import * as ABI from "../deployments/mainnet/Bonding.json"; // Contract ABI

const inter = new ethers.utils.Interface(ABI.abi);

// const possibleFunctionNames = ABI.abi.map((a) => a.name);
// // console.log("Functions available: ", possibleFunctionNames.join(", "));

const BONDING_CONTRACT_ADDRESS = "0x831e3674Abc73d7A3e9d8a9400AF2301c32cEF0C";
const API_URL = "https://api.etherscan.io/api";
const CONTRACT_GENESIS_BLOCK = 12595544;
const DEFAULT_OUTPUT_NAME = "bonding_transactions.json";

type EtherscanResponse = {
  status: string;
  message: string;
  result: Transaction[];
};

type Transaction = {
  isError: "0" | "1";
  input: string;
  hash: string;
  to: string;
  blockNumber: string;
  contractAddress: string;
  timeStamp: string;
};

type CliArgs = {
  path: string;
  startBlock: number;
  endBlock?: number;
  name:
    | ""
    | "deposit"
    | "setBlockCountInAWeek"
    | "crvPriceReset"
    | "uADPriceReset";
  isError: boolean;
};

type ParsedTransaction = {
  name: string;
  inputs: Record<string, string>;
  blockNumber: string;
  isError: boolean;
  timestamp: string;
  transaction: Transaction;
};

task(
  "getBondingContracts",
  "Extract bonding contracts from Etherscan API and save them to a file"
)
  .addPositionalParam(
    "path",
    "The path to store the bonding contracts",
    `./${DEFAULT_OUTPUT_NAME}`,
    types.string
  )
  .addOptionalParam(
    "startBlock",
    "The starting block for the Etherscan request (defaults is contract creation block)",
    CONTRACT_GENESIS_BLOCK,
    types.int
  )
  .addOptionalParam(
    "endBlock",
    "The end block for the Etherscan request (defaults to latest block)",
    undefined,
    types.int
  )
  .addOptionalParam(
    "name",
    "The function name (use empty string for all) (ex: deposit, crvPriceReset, uADPriceReset, setBlockCountInAWeek)",
    "deposit",
    types.string
  )
  .addOptionalParam(
    "isError",
    "Select transactions that were errors",
    false,
    types.boolean
  )
  .setAction(async (taskArgs: CliArgs) => {
    console.log("Arguments: ", taskArgs);
    if (!process.env.ETHERSCAN_API_KEY)
      throw new Error("ETHERSCAN_API_KEY environment variable must be set");

    const parsedPath = path.parse(taskArgs.path);
    if (!fs.existsSync(parsedPath.dir))
      throw new Error(`Path ${parsedPath.dir} does not exist`);

    try {
      const response = await fetchEtherscanBondingContract(taskArgs);
      const transactions = parseTransactions(response.result as Transaction[]);
      console.log("Total results: ", transactions.length);
      const filteredTransactions = filterTransactions(transactions, taskArgs);
      console.log("Filtered results: ", filteredTransactions.length);
      console.table(filteredTransactions, [
        "name",
        "inputs",
        "blockNumber",
        "isError",
        "timestamp",
      ]);
      writeToDisk(filteredTransactions, taskArgs.path);
      console.log("Results saved to: ", path.resolve(taskArgs.path));
    } catch (e) {
      console.error("There was an issue with the task", e);
    }
  });

async function fetchEtherscanBondingContract(
  filter: CliArgs
): Promise<EtherscanResponse> {
  const startBlock = filter.startBlock;
  const endBlock = filter.endBlock || (await fetchLatestBlockNumber());
  return fetchEtherscanApi(
    generateEtherscanQuery(BONDING_CONTRACT_ADDRESS, startBlock, endBlock)
  );
}

async function fetchLatestBlockNumber(): Promise<number> {
  console.log("Fetching latest block number...");
  const response = await fetchEtherscanApi({
    module: "proxy",
    action: "eth_blockNumber",
    apiKey: process.env.ETHERSCAN_API_KEY || "",
  });
  const latestBlockNumber = parseInt(response.result, 16);
  console.log("Latest block number: ", latestBlockNumber);
  return latestBlockNumber;
}

async function fetchEtherscanApi(query: Record<string, string>) {
  const response = await fetch(
    `${API_URL}?${new URLSearchParams(query).toString()}`
  );
  return await response.json();
}

function generateEtherscanQuery(
  address: string,
  startblock: number,
  endblock: number
): Record<string, string> {
  return {
    module: "account",
    action: "txlist",
    address: address, // This is the bonding smart contract right?
    startblock: startblock.toString(),
    endblock: endblock.toString(),
    sort: "asc",
    apiKey: process.env.ETHERSCAN_API_KEY || "",
  };
}

function parseTransactions(transactions: Transaction[]): ParsedTransaction[] {
  return transactions.map((t) => {
    let parsedTransaction: ParsedTransaction = {
      name: "",
      inputs: {},
      blockNumber: t.blockNumber,
      isError: t.isError === "1",
      timestamp: new Date(parseInt(t.timeStamp) * 1000).toISOString(),
      transaction: t,
    };
    if (t.to) {
      const input = inter.parseTransaction({ data: t.input });
      parsedTransaction.name = input.name;

      parsedTransaction.inputs = Object.fromEntries(
        Object.keys(input.args)
          .filter((k) => !k.match(/[0-9]+/))
          .map((k) => {
            return [k, input.args[k].toString()];
          })
      );
    } else {
      parsedTransaction.name = "Contract creation";
    }
    return parsedTransaction;
  });
}

function filterTransactions(
  transactions: ParsedTransaction[],
  args: CliArgs
): ParsedTransaction[] {
  return transactions.filter((t) => {
    return (!args.name || t.name === args.name) && args.isError === t.isError;
  });
}

function writeToDisk(transactions: ParsedTransaction[], path: string) {
  fs.writeFileSync(
    path,
    JSON.stringify(
      transactions.map((t) => t.transaction),
      null,
      2
    )
  );
}