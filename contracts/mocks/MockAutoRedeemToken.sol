// contracts/GLDToken.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockAutoRedeemToken is ERC20 {
    // Temporary placeholder name
    constructor(uint256 initialSupply) ERC20("AUTOREDEEM", "uAR") {
        _mint(msg.sender, initialSupply);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
