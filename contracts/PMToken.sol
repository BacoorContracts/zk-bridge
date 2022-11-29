// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import {
    ERC20,
    ERC20Permit
} from "oz-custom/contracts/oz/token/ERC20/extensions/draft-ERC20Permit.sol";

contract PMToken is ERC20Permit {
    constructor(
        string memory name_,
        string memory symbol_
    ) payable ERC20(name_, symbol_, 18) ERC20Permit(name_) {
        _mint(_msgSender(), 100_000_000 * 10 ** decimals);
    }

    function mint(address to_) external {
        _mint(to_, 1_000_000 * 10 ** decimals);
    }
}
