// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "oz-custom/contracts/oz/utils/structs/BitMaps.sol";

library PoseidonT3 {
    function poseidon(uint256[2] memory) public pure returns (uint256) {}
}

// Each incremental tree has certain properties and data that will
// be used to add new leaves.
struct IncrementalTreeData {
    uint256 depth; // Depth of the tree (levels - 1).
    uint256 root; // Root hash of the tree.
    uint256 numberOfLeaves; // Number of leaves of the tree.
    BitMaps.BitMap knownRoots;
    mapping(uint256 => uint256) zeroes; // Zero hashes used for empty nodes (level -> zero hash).
    // The nodes of the subtrees used in the last addition of a leaf (level -> [left node, right node]).
    mapping(uint256 => uint256[2]) lastSubtrees; // Caching these values is essential to efficient appends.
}

error IncrementalMerkleTree__OutOfField();
error IncrementalMerkleTree__OutOfDepth();
error IncrementalMerkleTree__OutOfRange();
error IncrementalMerkleTree__LengthMismatch();
error IncrementalMerkleTree__AllocationExceeded();

/// @title Incremental binary Merkle tree.
/// @dev The incremental tree allows to calculate the root hash each time a leaf is added, ensuring
/// the integrity of the tree.
library IncrementalMerkleTree {
    using BitMaps for BitMaps.BitMap;

    uint256 internal constant MAX_DEPTH = 32;
    uint256 internal constant SNARK_SCALAR_FIELD =
        0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;

    /// @dev Initializes a tree.
    /// @param self: Tree data.
    /// @param depth: Depth of the tree.
    /// @param zero: Zero value to be used.
    function init(
        IncrementalTreeData storage self,
        uint256 depth,
        uint256 zero
    ) internal {
        if (zero >= SNARK_SCALAR_FIELD)
            revert IncrementalMerkleTree__OutOfField();
        if (depth == 0 || depth > MAX_DEPTH)
            revert IncrementalMerkleTree__OutOfDepth();

        self.depth = depth;

        for (uint256 i; i < depth; ) {
            self.zeroes[i] = zero;
            zero = PoseidonT3.poseidon([zero, zero]);

            unchecked {
                ++i;
            }
        }

        self.root = zero;
        self.knownRoots.set(zero);
    }

    /// @dev Inserts a leaf in the tree.
    /// @param self: Tree data.
    /// @param leaf: Leaf to be inserted.
    function insert(IncrementalTreeData storage self, uint256 leaf) internal {
        uint256 depth = self.depth;
        if (leaf >= SNARK_SCALAR_FIELD)
            revert IncrementalMerkleTree__OutOfField();
        uint256 numberOfLeaves = self.numberOfLeaves;
        if (numberOfLeaves >= 1 << depth)
            revert IncrementalMerkleTree__AllocationExceeded();

        uint256 index = numberOfLeaves;
        uint256 hash = leaf;

        for (uint256 i; i < depth; ) {
            if (index & 1 == 0) self.lastSubtrees[i] = [hash, self.zeroes[i]];
            else self.lastSubtrees[i][1] = hash;

            hash = PoseidonT3.poseidon(self.lastSubtrees[i]);
            index >>= 1;

            unchecked {
                ++i;
            }
        }

        self.root = hash;
        self.knownRoots.set(uint256(hash));
        unchecked {
            self.numberOfLeaves = ++numberOfLeaves;
        }
    }

    function isKnownRoot(
        IncrementalTreeData storage self_,
        uint256 root_
    ) internal view returns (bool) {
        return self_.knownRoots.get(root_);
    }

    /// @dev Updates a leaf in the tree.
    /// @param self: Tree data.
    /// @param leaf: Leaf to be updated.
    /// @param newLeaf: New leaf.
    /// @param proofSiblings: Array of the sibling nodes of the proof of membership.
    /// @param proofPathIndices: Path of the proof of membership.
    function update(
        IncrementalTreeData storage self,
        uint256 leaf,
        uint256 newLeaf,
        uint256[] calldata proofSiblings,
        uint256[] calldata proofPathIndices
    ) internal {
        require(
            verify(self, leaf, proofSiblings, proofPathIndices),
            "IncrementalBinaryTree: leaf is not part of the tree"
        );

        uint256 depth = self.depth;
        uint256 hash = newLeaf;

        uint256 updateIndex;
        uint256 proofPathIndice;
        for (uint256 i; i < depth; ) {
            proofPathIndice = proofPathIndices[i];
            updateIndex |= (proofPathIndice & 1) << i;
            if (proofPathIndice == 0) {
                if (proofPathIndice == self.lastSubtrees[i][1])
                    self.lastSubtrees[i][0] = hash;

                hash = PoseidonT3.poseidon([hash, proofPathIndice]);
            } else {
                if (proofPathIndice == self.lastSubtrees[i][0])
                    self.lastSubtrees[i][1] = hash;

                hash = PoseidonT3.poseidon([proofPathIndice, hash]);
            }

            unchecked {
                ++i;
            }
        }

        if (updateIndex >= self.numberOfLeaves)
            revert IncrementalMerkleTree__OutOfRange();

        self.root = hash;
        self.knownRoots.set(hash);
    }

    /// @dev Removes a leaf from the tree.
    /// @param self: Tree data.
    /// @param leaf: Leaf to be removed.
    /// @param proofSiblings: Array of the sibling nodes of the proof of membership.
    /// @param proofPathIndices: Path of the proof of membership.
    function remove(
        IncrementalTreeData storage self,
        uint256 leaf,
        uint256[] calldata proofSiblings,
        uint256[] calldata proofPathIndices
    ) internal {
        update(self, leaf, self.zeroes[0], proofSiblings, proofPathIndices);
    }

    /// @dev Verify if the path is correct and the leaf is part of the tree.
    /// @param self: Tree data.
    /// @param leaf: Leaf to be removed.
    /// @param proofSiblings: Array of the sibling nodes of the proof of membership.
    /// @param proofPathIndices: Path of the proof of membership.
    /// @return True or false.
    function verify(
        IncrementalTreeData storage self,
        uint256 leaf,
        uint256[] calldata proofSiblings,
        uint256[] calldata proofPathIndices
    ) private view returns (bool) {
        uint256 scalarField = SNARK_SCALAR_FIELD;
        if (leaf >= scalarField) revert IncrementalMerkleTree__OutOfField();

        uint256 depth = self.depth;
        if (proofPathIndices.length != depth || proofSiblings.length != depth)
            revert IncrementalMerkleTree__LengthMismatch();

        uint256 hash = leaf;

        uint256 proofSibling;
        for (uint256 i; i < depth; ) {
            proofSibling = proofSiblings[i];
            if (proofSibling >= scalarField)
                revert IncrementalMerkleTree__OutOfField();

            hash = proofSibling == 0
                ? PoseidonT3.poseidon([hash, proofSibling])
                : PoseidonT3.poseidon([proofSibling, hash]);

            unchecked {
                ++i;
            }
        }

        return hash == self.root;
    }
}
