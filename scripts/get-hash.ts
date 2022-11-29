import { Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat";
const artifact = require("../MiMC220.json");
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
    const provider = ethers.getDefaultProvider();
    const abi = [
        "function MiMCSponge(uint256 xLin_, uint256 xRin_, uint256 k) external pure returns (uint256 xL, uint256 xR)",
    ];
    const hasher: Contract = new Contract(
        process.env.HASHER || "0xaf848e5b1fc40ed6a25bc0cfc00d3f0c64e32d73",
        abi,
        provider,
    );

    const { xL, xR } = await hasher.MiMCSponge(1, 7, 2006);

    console.log(`Result: xL=${xL}, xR=${xR}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
