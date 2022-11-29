// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IMultichainDeployer {
    function deploy(
        uint256 amount_,
        bytes32 salt_,
        bytes calldata bytecode_
    ) external payable;
}
