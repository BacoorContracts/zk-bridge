const { buildPoseidon } = require("circomlibjs");
const { ethers, BigNumber } = require("ethers");
const FileSystem = require("fs");
const { IncrementalMerkleTree } = require("@zk-kit/incremental-merkle-tree");
const { plonk } = require("snarkjs")

function createDeposit(hasher, nullifier, leafIdx, token, value) {
    let deposit = {
        nullifier: nullifier,
        nullifierHash: hasher([nullifier, value, token, leafIdx]),
        commitment: hasher([nullifier, 0])
    };
    Object.keys(deposit).forEach((k,) => deposit[k] = BigNumber.from(deposit[k]).toString())
    return deposit
}

async function prove(witness) {
    const wasmPath = './build/withdraw_js/withdraw.wasm'
    const zkeyPath = './build/circuit_final.zkey'

    const { proof, publicSignals } = await plonk.fullProve(witness, wasmPath, zkeyPath)
    const solProof = await plonk.exportSolidityCallData(proof, publicSignals)

    return solProof
}

async function main() {
    //const babyJub = await buildBabyjub();
    const poseidon = await buildPoseidon();
    const poseidonHash = inputs => {
        const hash = poseidon(inputs.map(x => BigNumber.from(x).toBigInt()));
        // Make the number within the field size
        const hashStr = poseidon.F.toString(hash);
        // Make it a valid hex string
        const hashHex = BigNumber.from(hashStr).toHexString();
        // pad zero to make it 32 bytes, so that the output can be taken as a bytes32 contract argument
        const bytes32 = ethers.utils.hexZeroPad(hashHex, 32);
        return bytes32;
    };
    //const pedersen = await buildPedersenHash();
    // const pedersenHash = (data) => babyJub.unpackPoint(pedersen.hash(data))[0]
    //   const poseidonHash = (x, y) => {
    //     return ethers.utils.hexlify(poseidon([x, y]));
    //   };
    //const pedersenHash = x => ethers.utils.hexlify(pedersen.hash(ethers.utils.arrayify(x)));
    const tree = new IncrementalMerkleTree(
        poseidonHash,
        20,
        "21663839004416932945382355908790599225266501822907911457504978515578255421292",
        2,
    );

    const leafIdx = tree.leaves.length
    const nullifier = BigNumber.from(ethers.utils.randomBytes(32)).toString()
    const token = BigNumber.from("0xE1C55Fa51E1cCfd69A2F2De88A9E74469CE33123").toString()
    const value = ethers.utils.parseEther("1432").toString()
    const deposit = createDeposit(poseidonHash, nullifier, leafIdx, token, value);

    tree.insert(deposit.commitment);

    const proof = tree.createProof(leafIdx);
    console.log(proof);
    const input = {
        // public snark inputs
        root: BigNumber.from(proof.root).toString(),
        value: ethers.utils.parseEther("1432").toString(),
        token: token,
        nullifierHash: deposit.nullifierHash,
        fee: ethers.utils.parseEther("0.001").toString(),
        relayer: BigNumber.from("0x3F579e98e794B870aF2E53115DC8F9C4B2A1bDA6").toString(),
        recipient: BigNumber.from("0x5a97007409617aFd83bA59d40faF1A38F0C7cEBE").toString(),

        // Private snark inputs
        nullifier: deposit.nullifier,
        pathIndices: proof.pathIndices,
        pathElements: proof.siblings.map(x => [BigNumber.from(x[0]).toString()]
            //typeof x[0] === "string" ? [BigNumber.from(x[0]).toString()] : [BigNumber.from(x[0]).toString()],
        ),
    };

    console.log(input)

    console.log("Proving: ...")
    const start = (new Date()).getTime()
    const solProof = await prove(input)
    console.log(solProof)
    //console.log(input);
    const end = (new Date()).getTime() - start

    console.log("Execution time", end)
    
    // FileSystem.writeFile("input.json", JSON.stringify(input), error => {
    //     if (error) throw error;
    // });
}

main();
