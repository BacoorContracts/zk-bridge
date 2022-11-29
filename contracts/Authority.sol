// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "oz-custom/contracts/oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "oz-custom/contracts/oz-upgradeable/security/PausableUpgradeable.sol";
import "oz-custom/contracts/internal-upgradeable/ProxyCheckerUpgradeable.sol";
import "oz-custom/contracts/internal-upgradeable/BlacklistableUpgradeable.sol";
import "oz-custom/contracts/oz-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import "./libraries/Roles.sol";
import "./interfaces/IAuthority.sol";

contract Authority is
    IAuthority,
    UUPSUpgradeable,
    PausableUpgradeable,
    ProxyCheckerUpgradeable,
    BlacklistableUpgradeable,
    AccessControlEnumerableUpgradeable
{
    /// @dev value is equal to keccak256("Authority_v1")
    bytes32 public constant VERSION =
        0x095dd5e04e0f3f5bce98e4ee904d9f7209827187c4201f036596b2f7fdd602e7;

    // /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }

    function init() external initializer {
        __Pausable_init_unchained();

        address sender = _msgSender();

        _grantRole(DEFAULT_ADMIN_ROLE, sender);

        _grantRole(Roles.SIGNER_ROLE, sender);
        _grantRole(Roles.PAUSER_ROLE, sender);
        _grantRole(Roles.MINTER_ROLE, sender);
        _grantRole(Roles.OPERATOR_ROLE, sender);
        _grantRole(Roles.UPGRADER_ROLE, sender);

        _setRoleAdmin(Roles.PAUSER_ROLE, Roles.OPERATOR_ROLE);
        _setRoleAdmin(Roles.MINTER_ROLE, Roles.OPERATOR_ROLE);
    }

    function setRoleAdmin(
        bytes32 role,
        bytes32 adminRole
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRoleAdmin(role, adminRole);
    }

    function requestAccess(bytes32 role) external whenNotPaused {
        address origin = _txOrigin();
        _checkRole(Roles.OPERATOR_ROLE, origin);

        address sender = _msgSender();
        _onlyProxy(sender, origin);

        _grantRole(Roles.PROXY_ROLE, sender);
        if (role != 0) _grantRole(role, sender);

        emit ProxyAccessGranted(sender);
    }

    function pause() external onlyRole(Roles.PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(Roles.PAUSER_ROLE) {
        _unpause();
    }

    function paused()
        public
        view
        override(IAuthority, PausableUpgradeable)
        returns (bool)
    {
        return PausableUpgradeable.paused();
    }

    function setUserStatus(
        address account_,
        bool status_
    )
        external
        override(BlacklistableUpgradeable, IBlacklistableUpgradeable)
        whenPaused
        onlyRole(Roles.PAUSER_ROLE)
    {
        _setUserStatus(account_, status_);
        if (status_) emit Blacklisted(account_);
        else emit Whitelisted(account_);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyRole(Roles.UPGRADER_ROLE) {}

    uint256[46] private __gap;
}
