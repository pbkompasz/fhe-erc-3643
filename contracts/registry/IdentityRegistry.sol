// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "./interfaces/ITrustedIssuersRegistry.sol";
import "./interfaces/IIdentityRegistryStorage.sol";
import "./interfaces/IIdentityRegistry.sol";
import "./interfaces/IClaimTopicsRegistry.sol";
import "./storage/IRStorage.sol";
import "../roles/AgentRole.sol";
import "../identity/interfaces/IClaimIssuer.sol";
import "../identity/interfaces/IIdentity.sol";

abstract contract IdentityRegistry is IIdentityRegistry, AgentRole, IRStorage {
    /**
     *  @dev the constructor initiates the Identity Registry smart contract
     *  @param _trustedIssuersRegistry the trusted issuers registry linked to the Identity Registry
     *  @param _claimTopicsRegistry the claim topics registry linked to the Identity Registry
     *  @param _identityStorage the identity registry storage linked to the Identity Registry
     *  emits a `ClaimTopicsRegistrySet` event
     *  emits a `TrustedIssuersRegistrySet` event
     *  emits an `IdentityStorageSet` event
     */
    constructor(address _trustedIssuersRegistry, address _claimTopicsRegistry, address _identityStorage) {
        require(
            _trustedIssuersRegistry != address(0) &&
                _claimTopicsRegistry != address(0) &&
                _identityStorage != address(0),
            "invalid argument - zero address"
        );
        _tokenTopicsRegistry = IClaimTopicsRegistry(_claimTopicsRegistry);
        _tokenIssuersRegistry = ITrustedIssuersRegistry(_trustedIssuersRegistry);
        _tokenIdentityStorage = IIdentityRegistryStorage(_identityStorage);
        emit ClaimTopicsRegistrySet(_claimTopicsRegistry);
        emit TrustedIssuersRegistrySet(_trustedIssuersRegistry);
        emit IdentityStorageSet(_identityStorage);
    }

    function updateIdentity(eaddress _userAddress, IIdentity _identity) external override onlyAgent {
        IIdentity oldIdentity = identity(_userAddress);
        _tokenIdentityStorage.modifyStoredIdentity(_userAddress, _identity);
        emit IdentityUpdated(oldIdentity, _identity);
    }

    function updateCountry(eaddress _userAddress, euint16 _country) external override onlyAgent {
        _tokenIdentityStorage.modifyStoredInvestorCountry(_userAddress, _country);
        emit CountryUpdated(_userAddress, _country);
    }

    function deleteIdentity(eaddress _userAddress) external override onlyAgent {
        IIdentity oldIdentity = identity(_userAddress);
        _tokenIdentityStorage.removeIdentityFromStorage(_userAddress);
        emit IdentityRemoved(_userAddress, oldIdentity);
    }

    function setIdentityRegistryStorage(address _identityRegistryStorage) external override onlyOwner {
        _tokenIdentityStorage = IIdentityRegistryStorage(_identityRegistryStorage);
        emit IdentityStorageSet(_identityRegistryStorage);
    }

    function setClaimTopicsRegistry(address _claimTopicsRegistry) external override onlyOwner {
        _tokenTopicsRegistry = IClaimTopicsRegistry(_claimTopicsRegistry);
        emit ClaimTopicsRegistrySet(_claimTopicsRegistry);
    }

    function setTrustedIssuersRegistry(address _trustedIssuersRegistry) external override onlyOwner {
        _tokenIssuersRegistry = ITrustedIssuersRegistry(_trustedIssuersRegistry);
        emit TrustedIssuersRegistrySet(_trustedIssuersRegistry);
    }

    // solhint-disable-next-line code-complexity
    function isVerified(eaddress _userAddress) external view override returns (bool) {
        if (address(identity(_userAddress)) == address(0)) {
            return false;
        }
        euint4[] memory requiredClaimTopics = _tokenTopicsRegistry.getClaimTopics();
        if (requiredClaimTopics.length == 0) {
            return true;
        }

        euint8 foundClaimTopic;
        euint8 scheme;
        address issuer;
        address dataContainer;
        uint256 claimTopic;
        for (claimTopic = 0; claimTopic < requiredClaimTopics.length; claimTopic++) {
            IClaimIssuer[] memory trustedIssuers = _tokenIssuersRegistry.getTrustedIssuersForClaimTopic(
                requiredClaimTopics[claimTopic]
            );

            if (trustedIssuers.length == 0) {
                return false;
            }

            bytes32[] memory claimIds = new bytes32[](trustedIssuers.length);
            for (uint256 i = 0; i < trustedIssuers.length; i++) {
                claimIds[i] = keccak256(abi.encode(trustedIssuers[i], requiredClaimTopics[claimTopic]));
            }

            for (uint256 j = 0; j < claimIds.length; j++) {
                (foundClaimTopic, scheme, issuer, dataContainer) = identity(_userAddress).getClaim(claimIds[j]);

                // if (foundClaimTopic == requiredClaimTopics[claimTopic]) {
                // try
                // IClaimIssuer(issuer).isClaimValid(
                //     identity(_userAddress),
                //     requiredClaimTopics[claimTopic],
                //     sig,
                //     data
                // )
                // returns (bool _validity) {
                //     if (_validity) {
                //         j = claimIds.length;
                //     }
                //     if (!_validity && j == (claimIds.length - 1)) {
                //         return false;
                //     }
                // } catch {
                //     if (j == (claimIds.length - 1)) {
                //         return false;
                //     }
                // }
                // } else if (j == (claimIds.length - 1)) {
                //     return false;
                // }
            }
        }
        return true;
    }

    function investorCountry(eaddress _userAddress) external view override returns (euint16) {
        return _tokenIdentityStorage.storedInvestorCountry(_userAddress);
    }

    function issuersRegistry() external view override returns (ITrustedIssuersRegistry) {
        return _tokenIssuersRegistry;
    }

    function topicsRegistry() external view override returns (IClaimTopicsRegistry) {
        return _tokenTopicsRegistry;
    }

    function identityStorage() external view override returns (IIdentityRegistryStorage) {
        return _tokenIdentityStorage;
    }

    function contains(eaddress _userAddress) external view override returns (bool) {
        if (address(identity(_userAddress)) == address(0)) {
            return false;
        }
        return true;
    }

    function registerIdentity(eaddress _userAddress, IIdentity _identity, euint16 _country) public override onlyAgent {
        _tokenIdentityStorage.addIdentityToStorage(_userAddress, _identity, _country);
        emit IdentityRegistered(_userAddress, _identity);
    }

    function identity(eaddress _userAddress) public view override returns (IIdentity) {
        return _tokenIdentityStorage.storedIdentity(_userAddress);
    }
}
