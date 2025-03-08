import * as fs from "fs";
import * as path from "path";
import { network } from "hardhat";

export interface BroadcastTransaction {
  hash: string;
  transactionType: string;
  contractName: string;
  contractAddress: string;
}

export interface BroadcastData {
  transactions: BroadcastTransaction[];
}

export function getContractAddressFromBroadcast(contractName: string): string {
  const chainId = network.config.chainId;
  if (!chainId) {
    throw new Error("Chain ID not found");
  }

  const broadcastFilePath = path.resolve(
    __dirname,
    `../../broadcast/PHTDeployment.s.sol/${chainId}/run-latest.json`
  );

  if (!fs.existsSync(broadcastFilePath)) {
    throw new Error(`Broadcast file not found at ${broadcastFilePath}`);
  }

  const broadcastData = JSON.parse(
    fs.readFileSync(broadcastFilePath, "utf8")
  ) as BroadcastData;

  const transaction = broadcastData.transactions.find(
    (tx) =>
      (tx.transactionType === "CREATE" || tx.transactionType === "CREATE2") &&
      tx.contractName === contractName
  );

  if (!transaction) {
    throw new Error(`Contract ${contractName} not found in broadcast data`);
  }

  return transaction.contractAddress;
}
