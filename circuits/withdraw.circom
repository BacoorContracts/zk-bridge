pragma circom 2.0.0;

include "merkleTree.circom";

include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";


// Verifies that commitment that corresponds to given secret and nullifier is included in the merkle tree of deposits
template Withdraw(levels) {
    signal input root;
    signal input value;
    signal input token;
    signal input nullifierHash;

    // not taking part in any computations
    signal input fee;      
    signal input relayer;  
    signal input recipient;

    // private inputs
    //signal input secret;
    signal input nullifier;
    signal input pathIndices[levels];
    signal input pathElements[levels][1];

    component leafIndexNum = Bits2Num(levels);
    for (var i = 0; i < levels; i++) {
        leafIndexNum.in[i] <== pathIndices[i];
    }

    component nullifierHasher = Poseidon(4);
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHasher.inputs[1] <== value;
    nullifierHasher.inputs[2] <== token;
    nullifierHasher.inputs[3] <== leafIndexNum.out;
    
    nullifierHasher.out === nullifierHash;

    component commitmentHasher = Poseidon(2);
    commitmentHasher.inputs[0] <== nullifier;
    commitmentHasher.inputs[1] <== 0;

    component tree = LeafExists(levels);
    tree.root <== root;
    tree.leaf <== commitmentHasher.out;

    for (var i = 0; i < levels; i++) {
        tree.path_index[i] <== pathIndices[i];
        tree.path_elements[i][0] <== pathElements[i][0];
    }

    // Add hidden signals to make sure that tampering with recipient or fee will invalidate the snark proof
    // Most likely it is not required, but it's better to stay on the safe side and it only takes 2 constraints
    // Squares are used to prevent optimizer from removing those constraints
    signal feeSquare;
    signal tokenSquare;
    signal valueSquare;
    signal refundSquare;
    signal relayerSquare;
    signal recipientSquare;

    feeSquare <== fee * fee;
    valueSquare <== value * value;
    tokenSquare <== token * token;
    relayerSquare <== relayer * relayer;
    recipientSquare <== recipient * recipient;
}

component main {
    public [
        root, 
        value, 
        token, 
        nullifierHash, 
        fee, 
        relayer, 
        recipient
    ]
} = Withdraw(20);
