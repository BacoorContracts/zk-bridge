import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import * as dotenv from "dotenv";
import "hardhat-contract-sizer";
import { HardhatUserConfig } from "hardhat/config";
const { subtask } = require("hardhat/config");
const { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } = require("hardhat/builtin-tasks/task-names");

subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS).setAction(async (_: any, __: any, runSuper: () => any) => {
    const paths = await runSuper();

    return paths.filter((p: string) => !p.endsWith(".t.sol"));
});

dotenv.config();

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.17",
        settings: {
            // metadata: {
            //     bytecodeHash: "ipfs",
            // },
            optimizer: {
                enabled: true,
                runs: 1_000_000,
            },
            //evmVersion: "london"
        },
    },
    etherscan: {
        apiKey: {
            avalancheFujiTestnet: process.env.FUJI_API_KEY || "",
            bscTestnet: process.env.TBSC_API_KEY || "",
            goerli: process.env.ETH_API_KEY || "",
            bsc: process.env.TBSC_API_KEY || "",
        },
    },
    networks: {
        fuji: {
            url: "https://api.avax-test.network/ext/bc/C/rpc",
            chainId: 43113,
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
        bsc: {
            url: "https://bsc-dataseed1.binance.org/",
            chainId: 56,
            accounts: process.env.MAINTAINER_KEY !== undefined ? [process.env.MAINTAINER_KEY] : [],
        },
        bscTest: {
            url: "https://bsctestapi.terminet.io/rpc",
            chainId: 97,
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
        goerli: {
            url: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
            chainId: 5,
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
        tomoTest: {
            url: "https://rpc.testnet.tomochain.com",
            chainId: 89,
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
    },
    contractSizer: {
        alphaSort: true,
        runOnCompile: true,
        disambiguatePaths: false,
    },
    gasReporter: {
        currency: "USD",
        enabled: true,
        excludeContracts: [],
        src: "./contracts",
    },
};

export default config;
