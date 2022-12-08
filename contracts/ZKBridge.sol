// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./internal/Base.sol";
import "oz-custom/contracts/internal/FundForwarder.sol";

import "./interfaces/IZKBridge.sol";
import "./interfaces/IAuthority.sol";
import "oz-custom/contracts/internal/interfaces/IWithdrawable.sol";

import {
    BitMaps,
    IncrementalTreeData,
    IncrementalMerkleTree
} from "./libraries/IncrementalMerkleTree.sol";
import "oz-custom/contracts/libraries/Bytes32Address.sol";

contract ZKBridge is Base, IZKBridge, FundForwarder {
    using BitMaps for BitMaps.BitMap;
    using Bytes32Address for address;
    using IncrementalMerkleTree for IncrementalTreeData;

    /// @dev value is equal to keccak256("ZKBridge_v1")
    bytes32 public constant VERSION =
        0xf4bf07e827f4c8c7388905ad771e71f3057b88af67d838d74e682d514b8b35ac;

    IVerifier public verifier;

    BitMaps.BitMap private __supportedTokens;
    mapping(address => address) public wrapped;

    BitMaps.BitMap private __commitments;
    BitMaps.BitMap private __bridgeStates;
    BitMaps.BitMap private __nullifierHashes;
    IncrementalTreeData private __merkleTree;

    constructor(
        uint256 zeroValue_,
        uint256 merkleHeight_,
        ITreasury vault_,
        IAuthority authority_,
        IVerifier verififer_
    )
        payable
        FundForwarder(address(vault_))
        Base(authority_, Roles.TREASURER_ROLE)
    {
        verifier = verififer_;
        __merkleTree.init(merkleHeight_, zeroValue_);
    }

    function updateVerifier(
        IVerifier verifier_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        if (address(verifier_) == address(0)) revert ZKBridge__NonZeroAddress();

        emit VerifierUpdated(verifier, verifier_);

        verifier = verifier_;
    }

    function addWrappedTokens(
        address[] calldata tokens_,
        address[] calldata wrappers_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        uint256 length = tokens_.length;
        if (length != wrappers_.length) revert ZKBridge__LengthMismatch();

        address token;
        for (uint256 i; i < length; ) {
            token = tokens_[i];
            wrapped[token] = wrappers_[i];
            __supportedTokens.set(token.fillLast96Bits());
            unchecked {
                ++i;
            }
        }
    }

    function addBridgeState(
        uint256 stateRoot_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        __bridgeStates.set(stateRoot_);

        emit NewBridgeState(stateRoot_);
    }

    function deposit(
        address account_,
        address token_,
        uint256 value_,
        uint256 commitment_
    ) external onlyRole(Roles.PROXY_ROLE) {
        if (__commitments.get(commitment_))
            revert ZKBridge__UsedCommitment(commitment_);

        uint256 leafIdx = __merkleTree.numberOfLeaves;

        __commitments.set(commitment_);
        __merkleTree.insert(commitment_);

        emit Deposited(
            token_,
            account_,
            value_,
            __merkleTree.root,
            leafIdx,
            commitment_
        );
    }

    function withdraw(
        address,
        address,
        uint256 fee_,
        Input calldata input_,
        bytes calldata proofs_
    ) external onlyRole(Roles.PROXY_ROLE) {
        if (!__supportedTokens.get(input_.token.fillLast96Bits()))
            revert ZKBridge__WrappedTokenNotSupported(input_.token);

        if (!__bridgeStates.get(input_.root))
            revert ZKBridge__UnknownRoot(input_.root);

        if (__nullifierHashes.get(input_.nullifierHash))
            revert ZKBridge__AlreadySpent(input_.nullifierHash);

        __nullifierHashes.set(input_.nullifierHash);

        __verifyProof(fee_, input_, proofs_);

        IWithdrawable(vault).withdraw(
            wrapped[input_.token],
            input_.recipient,
            input_.value
        );

        emit Withdrawn(
            input_.token,
            input_.recipient,
            input_.value,
            input_.nullifierHash,
            input_.relayer,
            fee_
        );
    }

    function __verifyProof(
        uint256 fee_,
        Input calldata input_,
        bytes calldata proofs_
    ) private view {
        uint256[] memory inputs = new uint256[](7);
        inputs[0] = input_.root;
        inputs[1] = input_.value;
        inputs[2] = input_.token.fillLast96Bits();
        inputs[3] = input_.nullifierHash;
        inputs[4] = fee_;
        inputs[5] = input_.relayer.fillLast96Bits();
        inputs[6] = input_.recipient.fillLast96Bits();
        if (!verifier.verifyProof(proofs_, inputs))
            revert ZKBridge__InvalidProof();
    }
}
