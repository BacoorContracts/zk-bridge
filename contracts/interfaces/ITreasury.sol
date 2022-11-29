// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "oz-custom/contracts/oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "oz-custom/contracts/internal-upgradeable/interfaces/IWithdrawableUpgradeable.sol";

interface ITreasury {
    error Treasury__Expired();
    error Treasury__LengthMismatch();
    error Treasury__InvalidSignature();

    event PaymentsUpdated(address[] indexed tokens);
    event PricesUpdated(address[] indexed tokens, uint256[] indexed prices);
    event PriceUpdated(
        IERC20Upgradeable indexed token,
        uint256 indexed from,
        uint256 indexed to
    );
    event PaymentRemoved(address indexed token);
    event PaymentsRemoved();

    function supportedPayment(address token_) external view returns (bool);

    function priceOf(address token_) external view returns (uint256);
}
