import { ethers } from "hardhat";

import type { DVD } from "../../types";
import { getSigners } from "../signers";

export async function deployDVDFixture(): Promise<DVD> {
  const signers = await getSigners();

  const contractFactory = await ethers.getContractFactory("DVD");
  const contract = await contractFactory.connect(signers.alice).deploy();
  await contract.waitForDeployment();

  return contract;
}
