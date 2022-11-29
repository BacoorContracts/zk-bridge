// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./interfaces/ICommandGate.sol";

import {
    IERC721,
    ERC721TokenReceiver
} from "oz-custom/contracts/oz/token/ERC721/ERC721.sol";
import "oz-custom/contracts/oz/token/ERC721/extensions/IERC721Enumerable.sol";
import "oz-custom/contracts/oz/utils/structs/BitMaps.sol";
import "oz-custom/contracts/oz/utils/introspection/ERC165Checker.sol";

import "oz-custom/contracts/internal/ProxyChecker.sol";
import "oz-custom/contracts/internal/FundForwarder.sol";
import "oz-custom/contracts/internal/MultiDelegatecall.sol";

import "./internal/Base.sol";

import "oz-custom/contracts/libraries/Bytes32Address.sol";

contract CommandGate is
    Base,
    ICommandGate,
    ProxyChecker,
    FundForwarder,
    MultiDelegatecall,
    ERC721TokenReceiver
{
    using ERC165Checker for address;
    using Bytes32Address for address;
    using BitMaps for BitMaps.BitMap;

    BitMaps.BitMap private __isWhitelisted;

    constructor(
        IAuthority authority_,
        ITreasury vault_
    ) payable Base(authority_, 0) FundForwarder(address(vault_)) {}

    function recoverNFTs(IERC721Enumerable token_) external {
        uint256 length = token_.balanceOf(address(this));
        for (uint256 i; i < length; ) {
            token_.safeTransferFrom(
                address(this),
                vault,
                token_.tokenOfOwnerByIndex(address(this), i)
            );
            unchecked {
                ++i;
            }
        }
    }

    function recoverNFT(IERC721 token_, uint256 tokenId_) external {
        token_.safeTransferFrom(address(this), vault, tokenId_);
    }

    function updateTreasury(
        ITreasury treasury_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        emit VaultUpdated(vault, address(treasury_));
        _changeVault(address(treasury_));
    }

    function whitelistAddress(
        address addr_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        if (addr_ == address(authority()) || addr_ == vault)
            revert CommandGate__InvalidArgument();
        __isWhitelisted.set(addr_.fillLast96Bits());

        emit Whitelisted(addr_);
    }

    function depositNativeTokenWithCommand(
        address contract_,
        bytes4 fnSig_,
        bytes calldata params_
    ) external payable whenNotPaused {
        if (!__isWhitelisted.get(contract_.fillLast96Bits()))
            revert CommandGate__UnknownAddress(contract_);

        _safeNativeTransfer(vault, msg.value);
        address sender = _msgSender();
        __executeTx(
            contract_,
            fnSig_,
            __concatDepositData(sender, address(0), msg.value, params_)
        );

        emit Commanded(
            contract_,
            fnSig_,
            params_,
            sender,
            address(0),
            msg.value
        );
    }

    function depositERC20WithCommand(
        IERC20 token_,
        uint256 value_,
        bytes4 fnSig_,
        address contract_,
        bytes memory data_
    ) external whenNotPaused {
        if (!__isWhitelisted.get(contract_.fillFirst96Bits()))
            revert CommandGate__UnknownAddress(contract_);

        address user = _msgSender();
        __checkUser(user);

        _safeERC20TransferFrom(token_, user, vault, value_);
        data_ = __concatDepositData(user, address(token_), value_, data_);
        __executeTx(contract_, fnSig_, data_);

        emit Commanded(contract_, fnSig_, data_, user, address(token_), value_);
    }

    function depositERC20PermitWithCommand(
        IERC20Permit token_,
        uint256 value_,
        uint256 deadline_,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes4 fnSig_,
        address contract_,
        bytes memory data_
    ) external whenNotPaused {
        if (!__isWhitelisted.get(contract_.fillLast96Bits()))
            revert CommandGate__UnknownAddress(contract_);
        address user = _msgSender();
        __checkUser(user);
        token_.permit(user, address(this), value_, deadline_, v, r, s);
        _safeERC20TransferFrom(
            IERC20(address(token_)),
            user,
            address(this),
            value_
        );
        data_ = __concatDepositData(user, address(token_), value_, data_);
        __executeTx(contract_, fnSig_, data_);

        emit Commanded(contract_, fnSig_, data_, user, address(token_), value_);
    }

    function onERC721Received(
        address,
        address from_,
        uint256 tokenId_,
        bytes calldata data_
    ) external override whenNotPaused returns (bytes4) {
        _checkBlacklist(from_);
        (address target, bytes4 fnSig, bytes memory data) = abi.decode(
            data_,
            (address, bytes4, bytes)
        );

        if (!__isWhitelisted.get(target.fillLast96Bits()))
            revert CommandGate__UnknownAddress(target);

        IERC721 nft = IERC721(_msgSender());
        nft.safeTransferFrom(address(this), vault, tokenId_, "");

        __executeTx(
            target,
            fnSig,
            __concatDepositData(from_, address(nft), tokenId_, data)
        );

        emit Commanded(target, fnSig, data, from_, address(nft), tokenId_);

        return this.onERC721Received.selector;
    }

    function depositERC721MultiWithCommand(
        uint256[] calldata tokenIds_,
        address[] calldata contracts_,
        bytes[] calldata data_
    ) external whenNotPaused {
        uint256 length = tokenIds_.length;
        address sender = _msgSender();
        __checkUser(sender);
        for (uint256 i; i < length; ) {
            IERC721(contracts_[i]).safeTransferFrom(
                sender,
                address(this),
                tokenIds_[i],
                data_[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    function __concatDepositData(
        address account_,
        address token_,
        uint256 value_,
        bytes memory data_
    ) private pure returns (bytes memory) {
        assembly {
            mstore(add(data_, 32), account_)
            mstore(add(data_, 64), token_)
            mstore(add(data_, 96), value_)
        }
        return data_;
    }

    function __executeTx(
        address target_,
        bytes4 fnSignature_,
        bytes memory params_
    ) private {
        (bool ok, ) = target_.call(abi.encodePacked(fnSignature_, params_));
        if (!ok) revert CommandGate__ExecutionFailed();
    }

    function __checkUser(address user_) private view {
        _checkBlacklist(user_);
        _onlyEOA(user_);
    }
}
