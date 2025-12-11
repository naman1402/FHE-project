// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {FHE} from "fhevm/lib/FHE.sol";

// Cannot inherit oz ERC20 contract because functions like transfer, approve, etc wont match the expected signatures
contract EncryptedERC20 {
    string private _name;
    string private _symbol;
    uint64 private _totalSupply;
    uint8 public constant decimals = 6;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function totalSupply() public view returns (uint64) {
        return _totalSupply;
    }
}