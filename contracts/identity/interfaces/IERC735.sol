// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";

/**
 * @dev interface of the ERC735 (Claim Holder) standard as defined in the EIP.
 */
interface IERC735 {
    /**
     * @dev Emitted when a claim was added.
     *
     * Specification: MUST be triggered when a claim was successfully added.
     */
    event ClaimAdded(bytes32 claimId, euint8 topic, euint8 scheme, address indexed issuer, address data);

    /**
     * @dev Emitted when a claim was removed.
     *
     * Specification: MUST be triggered when removeClaim was successfully called.
     */
    event ClaimRemoved(bytes32 claimId, euint8 topic, euint8 scheme, address indexed issuer, address data);

    /**
     * @dev Emitted when a claim was changed.
     *
     * Specification: MUST be triggered when addClaim was successfully called on an existing claimId.
     */
    event ClaimChanged(bytes32 claimId, euint8 topic, euint8 scheme, address indexed issuer, address data);

    /**
     * @dev Add or update a claim.
     *
     * Triggers Event: `ClaimAdded`, `ClaimChanged`
     *
     * Specification: Add or update a claim from an issuer.
     *
     * _signature is a signed message of the following structure:
     * `keccak256(abi.encode(address identityHolder_address, uint256 topic, bytes data))`.
     * Claim IDs are generated using `keccak256(abi.encode(address issuer_address + uint256 topic))`.
     */
    function addClaim(
        euint8 _topic,
        euint8 _scheme,
        address issuer,
        address data
    ) external returns (bytes32 claimRequestId);

    /**
     * @dev Removes a claim.
     *
     * Triggers Event: `ClaimRemoved`
     *
     * Claim IDs are generated using `keccak256(abi.encode(address issuer_address, uint256 topic))`.
     */
    function removeClaim(bytes32 _claimId) external returns (bool success);

    /**
     * @dev Get a claim by its ID.
     *
     * Claim IDs are generated using `keccak256(abi.encode(address issuer_address, uint256 topic))`.
     */
    function getClaim(
        bytes32 _claimId
    ) external view returns (euint8 topic, euint8 scheme, address issuer, address dataContainer);

    /**
     * @dev Returns an array of claim IDs by topic.
     */
    function getClaimIdsByTopic(euint8 _topic) external view returns (bytes32[] memory claimIds);
}
