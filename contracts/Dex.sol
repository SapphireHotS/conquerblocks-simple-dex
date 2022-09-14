// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Dex {

    mapping(string => address) public tokens;

    address public admin;

    mapping(address => mapping(string => uint)) public balances;

    constructor() {
        admin = msg.sender;
    }


    // Vamos a crear las funciones de agregado de tokens dentro del dex

    function addToken(string memory ticker, address tokenAddress) external onlyAdmin() { 
        tokens[ticker] = tokenAddress;
    }

    function removeToken(string memory ticker) external onlyAdmin() { 
        tokens[ticker] = address(0);
    }


    // Creamos las funciones para agregar y quitar liquidez.

    function deposit(uint _amount, string memory ticker) external tokenExist(ticker) {
        IERC20(tokens[ticker]).transferFrom(msg.sender, address(this), _amount);
        balances[msg.sender][ticker] += _amount;
    }


    function withdraw(uint _amount, string memory ticker) external tokenExist(ticker) {
        require(balances[msg.sender][ticker] >= _amount, 'Not enough tokens');
        balances[msg.sender][ticker] -= _amount;
        IERC20(tokens[ticker]).transfer(msg.sender, _amount);
    }

    modifier tokenExist(string memory ticker) {
        require(tokens[ticker] != address(0), 'Token not approved.');
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, 'Only admin can interact.');
        _;
    } 
}
