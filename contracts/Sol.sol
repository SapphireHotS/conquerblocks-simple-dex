// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Sol is ERC20 {

    constructor() ERC20('SOL', 'Solana Testing Token'){
        _mint(msg.sender, 10000 * (10 ** uint256(decimals())));
    }
}