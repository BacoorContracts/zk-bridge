// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IVerifier {
    function verifyProof(
        bytes memory proof,
        uint256[] memory pubSignals
    ) external view returns (bool);
}
