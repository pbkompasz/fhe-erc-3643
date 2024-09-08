// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";

contract Storage {
    struct Key {
        euint4[] purposes;
        euint4 keyType;
        bytes32 key;
    }

    struct Execution {
        address to;
        uint256 value;
        bytes data;
        bool approved;
        bool executed;
    }

    struct Claim {
        euint8 topic;
        euint8 schemeId;
        address issuer;
        address dataContainer;
    }

    uint256 internal _executionNonce;

    mapping(bytes32 => Key) internal _keys;

    // purpose 1 = MANAGEMENT
    // purpose 2 = ACTION
    // purpose 3 = CLAIM
    mapping(euint4 => bytes32[]) internal _keysByPurpose;

    mapping(uint256 => Execution) internal _executions;

    mapping(bytes32 => Claim) internal _claims;

    mapping(euint8 => bytes32[]) internal _claimsByTopic;

    bool internal _initialized = false;

    bool internal _canInteract = false;
}
