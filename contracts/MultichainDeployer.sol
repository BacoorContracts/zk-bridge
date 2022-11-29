// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import {
    Create2Deployer
} from "oz-custom/contracts/internal/DeterministicDeployer.sol";

import "./interfaces/IMultichainDeployer.sol";

contract MultichainDeployer is Create2Deployer, IMultichainDeployer {
    /// @dev value is equal to keccak256("MultichainDeployer_v1")
    bytes32 public constant VERSION =
        0x9eea8cb98c11fea36be219299200e6b67153ef85e64f26fbca079445a66e02d2;

    function deploy(
        uint256 amount_,
        bytes32 salt_,
        bytes calldata bytecode_
    ) external payable {
        _deploy(amount_, salt_, bytecode_);
    }
}
