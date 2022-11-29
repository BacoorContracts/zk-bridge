const fs = require("fs");
const outputPath = "MiMC220.json";
const lib = require("circomlibjs");

function main() {
    const contract = {
        contractName: "MiMC220",
        abi: lib.mimcSpongecontract.abi,
        bytecode: lib.mimcSpongecontract.createCode("mimcsponge", 220),
    };

    fs.writeFileSync(outputPath, JSON.stringify(contract));
}

main();
