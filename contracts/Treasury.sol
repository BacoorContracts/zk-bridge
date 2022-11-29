// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "oz-custom/contracts/internal-upgradeable/SignableUpgradeable.sol";
import "oz-custom/contracts/internal-upgradeable/ProxyCheckerUpgradeable.sol";
import "oz-custom/contracts/internal-upgradeable/WithdrawableUpgradeable.sol";
import "oz-custom/contracts/oz-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./internal-upgradeable/BaseUpgradeable.sol";

import "oz-custom/contracts/libraries/EnumerableSetV2.sol";
import "oz-custom/contracts/libraries/FixedPointMathLib.sol";

import "./interfaces/ITreasury.sol";
import {
    IERC721Upgradeable,
    ERC721TokenReceiverUpgradeable
} from "oz-custom/contracts/oz-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "oz-custom/contracts/oz-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";

contract Treasury is
    ITreasury,
    BaseUpgradeable,
    SignableUpgradeable,
    ProxyCheckerUpgradeable,
    WithdrawableUpgradeable,
    ERC721TokenReceiverUpgradeable
{
    using Bytes32Address for address;
    using FixedPointMathLib for uint256;
    using ERC165CheckerUpgradeable for address;
    using EnumerableSetV2 for EnumerableSetV2.AddressSet;

    ///@dev value is equal to keccak256("Treasury_v1")
    bytes32 public constant VERSION =
        0xea88ed743f2d0583b98ad2b145c450d84d46c8e4d6425d9e0c7cd0e4930fce2f;

    ///@dev value is equal to keccak256("Permit(address token,address to,uint256 value,uint256 deadline,uint256 nonce)")
    bytes32 private constant __PERMIT_TYPE_HASH =
        0x2ebfdfe4a977046f076938a5a375e2aed52779362e4769bb2efb0dd45b7fdb54;
    AggregatorV3Interface public priceFeed;

    mapping(bytes32 => uint256) private __priceOf;
    EnumerableSetV2.AddressSet private __payments;

    // /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() payable {
    //     _disableInitializers();
    // }

    function init(
        IAuthority authority_,
        AggregatorV3Interface priceFeed_
    ) external initializer {
        priceFeed = priceFeed_;

        __Base_init_unchained(authority_, 0);
        __Signable_init(type(Treasury).name, "1");
    }

    function updateTreasury(ITreasury treasury_) external override {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function withdraw(
        address token_,
        address to_,
        uint256 value_
    ) external override onlyRole(Roles.TREASURER_ROLE) {
        __withdraw(token_, to_, value_);
    }

    function withdraw(
        address token_,
        address to_,
        uint256 value_,
        uint256 deadline_,
        bytes calldata signature_
    ) external whenNotPaused {
        _checkBlacklist(to_);
        _onlyEOA(_msgSender());

        if (block.timestamp > deadline_) revert Treasury__Expired();
        if (
            !_hasRole(
                Roles.SIGNER_ROLE,
                _recoverSigner(
                    keccak256(
                        abi.encode(
                            __PERMIT_TYPE_HASH,
                            token_,
                            to_,
                            value_,
                            deadline_,
                            _useNonce(to_)
                        )
                    ),
                    signature_
                )
            )
        ) revert Treasury__InvalidSignature();

        __withdraw(token_, to_, value_);
    }

    function priceOf(address token_) external view returns (uint256) {
        if (token_ == address(0)) {
            AggregatorV3Interface _priceFeed = priceFeed;
            (, int256 usdUnit, , , ) = _priceFeed.latestRoundData();
            return
                uint256(usdUnit).mulDivDown(
                    1 ether,
                    10 ** _priceFeed.decimals()
                );
        }
        return __priceOf[token_.fillLast12Bytes()];
    }

    function updatePrices(
        address[] calldata tokens_,
        uint256[] calldata prices_
    ) external onlyRole(Roles.TREASURER_ROLE) {
        uint256 length = tokens_.length;
        if (length != prices_.length) revert Treasury__LengthMismatch();

        bytes32[] memory tokens;
        {
            address[] memory _tokens = tokens_;
            assembly {
                tokens := _tokens
            }
        }
        for (uint256 i; i < length; ) {
            __priceOf[tokens[i]] = prices_[i];
            unchecked {
                ++i;
            }
        }
        emit PricesUpdated(tokens_, prices_);
    }

    function updatePayments(
        address[] calldata tokens_
    ) external onlyRole(Roles.TREASURER_ROLE) {
        __payments.add(tokens_);
        emit PaymentsUpdated(tokens_);
    }

    function resetPayments() external onlyRole(Roles.TREASURER_ROLE) {
        __payments.remove();
        emit PaymentsRemoved();
    }

    function removePayment(
        address token_
    ) external onlyRole(Roles.TREASURER_ROLE) {
        if (__payments.remove(token_)) emit PaymentRemoved(token_);
    }

    function payments() external view returns (address[] memory) {
        return __payments.values();
    }

    function supportedPayment(address token_) public view returns (bool) {
        return __payments.contains(token_);
    }

    function __withdraw(address token_, address to_, uint256 value_) private {
        if (supportedPayment(token_)) {
            if (token_.supportsInterface(type(IERC721Upgradeable).interfaceId))
                IERC721Upgradeable(token_).safeTransferFrom(
                    address(this),
                    to_,
                    value_
                );
            else _safeTransfer(IERC20Upgradeable(token_), to_, value_);
            emit Withdrawn(token_, to_, value_);
        }
    }

    uint256[48] private __gap;
}
