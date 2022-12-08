import { Contract, ContractFactory } from "ethers";
import { ethers, upgrades } from "hardhat";
import { PMToken } from "../typechain-types";
const { poseidonContract } = require("circomlibjs");

async function main() {
    // const Authority: ContractFactory = await ethers.getContractFactory("Authority");
    // const authority = await upgrades.deployProxy(Authority, [], { initializer: "init", kind: "uups" });
    // await authority.deployed();

    // console.log("Authority Proxy Contract deployed to : ", authority.address);
    // console.log(
    //     "Authority Contract implementation address is : ",
    //     await upgrades.erc1967.getImplementationAddress(authority.address),
    // );

    // const Treasury: ContractFactory = await ethers.getContractFactory("Treasury");
    // const treasury: Contract = await upgrades.deployProxy(
    //     Treasury,
    //     [authority.address, "0x0A77230d17318075983913bC2145DB16C7366156"],
    //     { initializer: "init", kind: "uups" },
    // );
    // await treasury.deployed();

    // console.log("Treasury Proxy Contract deployed to : ", treasury.address);
    // console.log(
    //     "Treasury Contract implementation address is : ",
    //     await upgrades.erc1967.getImplementationAddress(treasury.address),
    // );

    // const CommandGate: ContractFactory = await ethers.getContractFactory("CommandGate");
    // const commandGate: Contract = await CommandGate.deploy(process.env.BSC_AUTHORITY, process.env.BSC_TREASURY);
    // await commandGate.deployed();

    // console.log(`CommandGate is deployed to: ${commandGate.address}`);

    // const Verifier: ContractFactory = await ethers.getContractFactory("PlonkVerifier");
    // const verifier: Contract = await Verifier.deploy();
    // await verifier.deployed();

    // console.log(`Verifier deployed to: ${verifier.address}`);

    // const poseidonT3ABI = poseidonContract.generateABI(2);
    // const poseidonT3Bytecode = poseidonContract.createCode(2);
    // const [signer] = await ethers.getSigners()
    // const PoseidonT3: ContractFactory = new ethers.ContractFactory(poseidonT3ABI, poseidonT3Bytecode, signer);
    // const poseidon: Contract = await PoseidonT3.deploy();
    // await poseidon.deployed();

    // console.log(`PoseidonT3 library has been deployed to: ${poseidon.address}`);

    const ZKBridge: ContractFactory = await ethers.getContractFactory("ZKBridge", {
        libraries: { PoseidonT3: process.env.BSC_POSEIDON },
    });

    const zkBridge: Contract = await ZKBridge.deploy(
        "21663839004416932945382355908790599225266501822907911457504978515578255421292",
        20,
        process.env.BSC_TREASURY,
        process.env.BSC_AUTHORITY,
        process.env.BSC_VERIFIER,
    );
    await zkBridge.deployed();

    console.log(`ZKBridge deployed to: ${zkBridge.address}`);

    // const Deployer: ContractFactory = await ethers.getContractFactory("MultichainDeployer");
    // const deployer: Contract = await Deployer.deploy();
    // await deployer.deployed();
    // console.log(`Deployed to ${deployer.address}`);
    // console.log(artifact)
    // const MiMC: ContractFactory = new ethers.ContractFactory(artifact.abi, artifact.bytecode)
    // const mimc: Contract = await MiMC.deploy()
    // await mimc.deployTransaction.wait()
    // console.log(`Hasher deployed to ${mimc.address}`)
    // console.log(poseidonContract);

    // const PMToken: ContractFactory = await ethers.getContractFactory("PMToken")
    // const token: Contract = await PMToken.deploy("PaymentToken", "PMT")
    // await token.deployed()

    // console.log("PMToken deployed to: ", token.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
