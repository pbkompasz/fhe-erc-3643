import { expect } from "chai";

import { asyncDecrypt, awaitAllDecryptionResults } from "../asyncDecrypt";
import { createInstances } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployDVDFixture } from "./DVD.fixture";

describe("DVD", function () {
  before(async function () {
    await initSigners();
    await asyncDecrypt();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const contract = await deployDVDFixture();
    this.contractAddress = await contract.getAddress();
    this.dvd = contract;
    this.instances = await createInstances(this.signers);
  });

  it("submit a simple request", async function () {
    const isQueFree = await this.dvd.isDecryptionQueFree();
    expect(isQueFree).to.equal(true);

    const myIstance = this.instances.alice;
    const userAddress = this.signers.alice.address;
    const contractAddress = this.contractAddress;

    const input = myIstance.createEncryptedInput(contractAddress, userAddress);
    const inputs = input.add4(0).add4(1).add32(100).encrypt();

    const transaction = await this.dvd.submitRequest(
      inputs.handles[0],
      inputs.handles[1],
      inputs.handles[2],
      inputs.inputProof,
    );
    await transaction.wait();

    await awaitAllDecryptionResults();

    const decryptResult = await this.dvd.getDecryptResult();
    expect(decryptResult).to.equal(404);
  });

  it("submit two imcompattible requests", async function () {
    const isQueFree = await this.dvd.isDecryptionQueFree();
    expect(isQueFree).to.equal(true);

    const myIstance = this.instances.alice;
    const userAddress = this.signers.alice.address;
    const contractAddress = this.contractAddress;

    const input = myIstance.createEncryptedInput(contractAddress, userAddress);
    const inputs = input.add4(0).add4(1).add32(100).encrypt();

    const transaction = await this.dvd.submitRequest(
      inputs.handles[0],
      inputs.handles[1],
      inputs.handles[2],
      inputs.inputProof,
    );
    await transaction.wait();

    const input2 = myIstance.createEncryptedInput(contractAddress, userAddress);
    const inputs2 = input2.add4(1).add4(0).add32(100).encrypt();

    const transaction2 = await this.dvd.submitRequest(
      inputs2.handles[0],
      inputs2.handles[1],
      inputs2.handles[2],
      inputs2.inputProof,
    );
    await transaction2.wait();

    const queSize = await this.dvd.getDecryptQueSize();
    expect(queSize).to.equal(2);
  });
});
