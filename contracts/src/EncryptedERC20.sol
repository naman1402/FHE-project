// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ebool, euint64, externalEuint64} from "fhevm/lib/EncryptedTypes.sol";
import {FHE} from "fhevm/lib/FHE.sol";
import {CoprocessorConfig} from "fhevm/lib/Impl.sol";
import {
    aclAdd,
    fhevmExecutorAdd,
    kmsVerifierAdd
} from "@fhevm-host-contracts/addresses/FHEVMHostAddresses.sol";

contract EncryptedERC20 {
    string private _name;
    string private _symbol;
    uint64 private _totalSupply;
    uint8 public constant decimals = 6;
    address public owner;

    mapping(address => euint64) internal _balances;

    event Transfer(address indexed from, address indexed to);
    event Mint(address indexed to, uint64 amount);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        owner = msg.sender;
                
        FHE.setCoprocessor(CoprocessorConfig({
            ACLAddress: aclAdd,
            CoprocessorAddress: fhevmExecutorAdd,
            KMSVerifierAddress: kmsVerifierAdd
        }));
    }


    /// @notice View function to get the name of the token
    /// @return The name of the token
    function name() public view returns (string memory) {
        return _name;
    }

    /// @notice View function to get the symbol of the token
    /// @return The symbol of the token
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /// @notice View function to get the total supply of the token
    /// @return The total supply of the token
    function totalSupply() public view returns (uint64) {
        return _totalSupply;
    }

    ///     
    function mint(uint64 amount) public virtual {
        require(msg.sender == owner);

        _balances[owner] = FHE.add(_balances[owner], amount);
        FHE.allowThis(_balances[owner]);
        FHE.allow(_balances[owner], owner);
        _totalSupply += amount;

        emit Mint(owner, amount);
    }

    /// @notice Transfer encrypted tokens to a specified address
    /// @param to The address to transfer to
    /// @param encryptedAmount The encrypted amount to be transferred
    /// @param inputProof The proof that the encrypted amount is valid
    /// @return A boolean that indicates if the operation was successful 
    function transfer(address to, externalEuint64 encryptedAmount, bytes calldata inputProof) public virtual returns (bool) {
        transfer(to, FHE.fromExternal(encryptedAmount, inputProof));
        return true;
    }

    /// @notice Transfer encrypted tokens to a specified address
    /// @param to The address to transfer to
    /// @param amount The encrypted amount to be transferred
    /// @return A boolean that indicates if the operation was successful
    function transfer(address to, euint64 amount) public virtual returns (bool) {
        require(FHE.isSenderAllowed(amount), "Sender is not allowed to use the encrypted amount");
        ebool canTransfer = FHE.le(amount, _balances[msg.sender]);
        _transfer(msg.sender, to, amount, canTransfer);
        return true;
    }

    /// @notice Get the encrypted balance of a user
    /// @param user The address of the user
    /// @return The encrypted balance of the user
    function balanceOf(address user) public view returns (euint64) {
        return _balances[user];
    }

    /// @notice Internal function to handle transfers
    /// @param from The address to transfer from
    /// @param to The address to transfer to
    /// @param amount The encrypted amount to be transferred
    /// @param canTransfer An encrypted boolean indicating if the transfer can proceed
    /// @dev If canTransfer is false, the transfer amount is treated as zero 
    function _transfer(address from, address to, euint64 amount, ebool canTransfer) internal virtual {
        euint64 transferValue = FHE.select(canTransfer, amount, FHE.asEuint64(0));

        // Update balances of from address
        euint64 newBalanceTo = FHE.add(_balances[to], transferValue);
        _balances[to] = newBalanceTo;
        FHE.allowThis(newBalanceTo);
        FHE.allow(newBalanceTo, to);
        
        // Update balances of to address
        euint64 newBalanceFrom = FHE.sub(_balances[from], transferValue);
        _balances[from] = newBalanceFrom;
        FHE.allowThis(newBalanceFrom);
        FHE.allow(newBalanceFrom, from);

        emit Transfer(from, to);
    }
}