// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.24;

import "./interfaces/IClaimIssuer.sol";
import "./Identity.sol";

abstract contract ClaimIssuer is IClaimIssuer, Identity {
    mapping(bytes32 => bool) public revokedClaims;

    constructor(address initialManagementKey) Identity(initialManagementKey, false) {}

    function revokeClaim(
        bytes32 _claimId,
        address _identity
    ) external override delegatedOnly onlyManager returns (bool) {
        euint8 foundClaimTopic;
        euint8 scheme;
        address issuer;
        address dataContainer;

        (foundClaimTopic, scheme, issuer, dataContainer) = Identity(_identity).getClaim(_claimId);

        require(!revokedClaims[_claimId], "Conflict: Claim already revoked");

        revokedClaims[_claimId] = true;
        emit ClaimRevoked(_claimId);
        return true;
    }

    function isClaimValid(
        IIdentity _identity,
        uint256 claimTopic,
        bytes memory data
    ) public override returns (ebool claimValid) {
        return _checkDataForClaim(claimTopic, data);
    }

    function _checkDataForClaim(uint256, bytes memory) internal returns (ebool) {
        return TFHE.asEbool(true);
    }

    function isClaimRevoked(bytes32 _claimId) public view override returns (bool) {
        if (revokedClaims[_claimId]) {
            return true;
        }

        return false;
    }
}
