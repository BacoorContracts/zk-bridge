// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IVerifier.sol";
import "./ITreasury.sol";

interface IZKBridge {
    error ZKBridge__InvalidProof();
    error ZKBridge__LengthMismatch();
    error ZKBridge__NonZeroAddress();
    error ZKBridge__UnknownRoot(uint256);
    error ZKBridge__AlreadySpent(uint256);
    error ZKBridge__UsedCommitment(uint256);
    error ZKBridge__WrappedTokenNotSupported(address);

    struct Input {
        uint256 root;
        uint256 value;
        address token;
        uint256 nullifierHash;
        address relayer;
        address recipient;
    }

    event NewBridgeState(uint256 indexed stateRoot);

    event VerifierUpdated(
        IVerifier indexed currentAddr,
        IVerifier indexed newAddr
    );

    event Deposited(
        address indexed token,
        address indexed account,
        uint256 indexed value,
        uint256 root,
        uint256 leafIdx,
        uint256 commitment
    );

    event Withdrawn(
        address indexed token,
        address indexed to,
        uint256 indexed value,
        uint256 nullifierHash,
        address relayer,
        uint256 fee
    );
}
