// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MockACL
 * @notice A mock ACL that allows all operations
 * @dev Used for testing - doesn't enforce any access control
 */
contract MockACL {
    event Allowed(address indexed sender, address indexed account, bytes32 indexed handle);
    event AllowedForDecryption(bytes32[] handlesList);

    address public fhevmExecutor;
    address public fheGasLimit;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function initialize(address _owner) external {
        owner = _owner;
    }

    function setFHEVMExecutor(address _executor) external {
        fhevmExecutor = _executor;
    }

    function setFheGasLimit(address _limit) external {
        fheGasLimit = _limit;
    }

    /// @notice Allow handle for account - always succeeds in mock
    function allow(bytes32 handle, address account) external {
        emit Allowed(msg.sender, account, handle);
    }

    /// @notice Allow handles for decryption
    function allowForDecryption(bytes32[] calldata handlesList) external {
        emit AllowedForDecryption(handlesList);
    }

    /// @notice Check if allowed - always returns true in mock
    function isAllowed(bytes32, address) external pure returns (bool) {
        return true;
    }

    /// @notice Check if sender is allowed - always returns true in mock
    function allowedOnBehalf(address, bytes32, address, address) external pure returns (bool) {
        return true;
    }

    /// @notice Always allow transient operations
    function allowTransient(bytes32, address) external pure {}

    /// @notice Always returns true for transient checks
    function isAllowedTransient(bytes32, address) external pure returns (bool) {
        return true;
    }

    /// @notice Clean up transient allows - no-op in mock
    function cleanTransientStorage() external pure {}
}
