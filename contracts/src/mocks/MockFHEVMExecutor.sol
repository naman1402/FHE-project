// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FheType} from "fhevm-host/shared/FheType.sol";

/**
 * @title MockFHEVMExecutor
 * @notice A mock FHEVMExecutor that emits events for FHE operations
 * @dev This mock is used for testing the coprocessor event capture.
 *      It doesn't perform actual FHE operations - it just emits events.
 */
contract MockFHEVMExecutor {
    // Events from FHEEvents.sol
    event FheAdd(address indexed caller, bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result);
    event FheSub(address indexed caller, bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result);
    event FheMul(address indexed caller, bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result);
    event FheLe(address indexed caller, bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result);
    event FheLt(address indexed caller, bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result);
    event FheGe(address indexed caller, bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result);
    event FheGt(address indexed caller, bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result);
    event FheEq(address indexed caller, bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result);
    event FheNe(address indexed caller, bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result);
    event FheIfThenElse(address indexed caller, bytes32 control, bytes32 ifTrue, bytes32 ifFalse, bytes32 result);
    event TrivialEncrypt(address indexed caller, uint256 pt, FheType toType, bytes32 result);
    event Cast(address indexed caller, bytes32 ct, FheType toType, bytes32 result);

    address public owner;
    address public aclAddress;
    uint256 private _handleCounter;

    constructor() {
        owner = msg.sender;
    }

    function initialize(address _owner, address _acl) external {
        owner = _owner;
        aclAddress = _acl;
    }

    /// @notice Generate a unique handle for ciphertext
    function _nextHandle(FheType fheType) internal returns (bytes32) {
        _handleCounter++;
        return bytes32(uint256(fheType) << 248 | _handleCounter);
    }

    // ===== FHE Operations (mock implementations that emit events) =====

    /// @notice Trivial encrypt - convert plaintext to ciphertext handle
    function trivialEncrypt(uint256 pt, uint8 toType) external returns (bytes32) {
        FheType fheType = FheType(toType);
        bytes32 result = _nextHandle(fheType);
        emit TrivialEncrypt(msg.sender, pt, fheType, result);
        return result;
    }

    /// @notice FHE Add - add two ciphertexts or ciphertext + scalar
    function fheAdd(bytes32 lhs, bytes32 rhs, bytes1 scalarByte) external returns (bytes32) {
        bytes32 result = _nextHandle(FheType.Uint64);
        emit FheAdd(msg.sender, lhs, rhs, scalarByte, result);
        return result;
    }

    /// @notice FHE Sub - subtract two ciphertexts or ciphertext - scalar
    function fheSub(bytes32 lhs, bytes32 rhs, bytes1 scalarByte) external returns (bytes32) {
        bytes32 result = _nextHandle(FheType.Uint64);
        emit FheSub(msg.sender, lhs, rhs, scalarByte, result);
        return result;
    }

    /// @notice FHE Mul - multiply two ciphertexts or ciphertext * scalar
    function fheMul(bytes32 lhs, bytes32 rhs, bytes1 scalarByte) external returns (bytes32) {
        bytes32 result = _nextHandle(FheType.Uint64);
        emit FheMul(msg.sender, lhs, rhs, scalarByte, result);
        return result;
    }

    /// @notice FHE Less-than-or-equal comparison
    function fheLe(bytes32 lhs, bytes32 rhs, bytes1 scalarByte) external returns (bytes32) {
        bytes32 result = _nextHandle(FheType.Bool);
        emit FheLe(msg.sender, lhs, rhs, scalarByte, result);
        return result;
    }

    /// @notice FHE Less-than comparison
    function fheLt(bytes32 lhs, bytes32 rhs, bytes1 scalarByte) external returns (bytes32) {
        bytes32 result = _nextHandle(FheType.Bool);
        emit FheLt(msg.sender, lhs, rhs, scalarByte, result);
        return result;
    }

    /// @notice FHE Greater-than-or-equal comparison
    function fheGe(bytes32 lhs, bytes32 rhs, bytes1 scalarByte) external returns (bytes32) {
        bytes32 result = _nextHandle(FheType.Bool);
        emit FheGe(msg.sender, lhs, rhs, scalarByte, result);
        return result;
    }

    /// @notice FHE Greater-than comparison
    function fheGt(bytes32 lhs, bytes32 rhs, bytes1 scalarByte) external returns (bytes32) {
        bytes32 result = _nextHandle(FheType.Bool);
        emit FheGt(msg.sender, lhs, rhs, scalarByte, result);
        return result;
    }

    /// @notice FHE Equal comparison
    function fheEq(bytes32 lhs, bytes32 rhs, bytes1 scalarByte) external returns (bytes32) {
        bytes32 result = _nextHandle(FheType.Bool);
        emit FheEq(msg.sender, lhs, rhs, scalarByte, result);
        return result;
    }

    /// @notice FHE Not-equal comparison
    function fheNe(bytes32 lhs, bytes32 rhs, bytes1 scalarByte) external returns (bytes32) {
        bytes32 result = _nextHandle(FheType.Bool);
        emit FheNe(msg.sender, lhs, rhs, scalarByte, result);
        return result;
    }

    /// @notice FHE If-Then-Else (select)
    function fheIfThenElse(bytes32 control, bytes32 ifTrue, bytes32 ifFalse) external returns (bytes32) {
        bytes32 result = _nextHandle(FheType.Uint64);
        emit FheIfThenElse(msg.sender, control, ifTrue, ifFalse, result);
        return result;
    }

    /// @notice Cast ciphertext to different type
    function cast(bytes32 ct, uint8 toType) external returns (bytes32) {
        FheType fheType = FheType(toType);
        bytes32 result = _nextHandle(fheType);
        emit Cast(msg.sender, ct, fheType, result);
        return result;
    }
}
