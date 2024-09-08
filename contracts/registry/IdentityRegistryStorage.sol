// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "../identity/interfaces/IIdentity.sol";
import "./interfaces/IIdentityRegistryStorage.sol";
import "./storage/IRSStorage.sol";
import "../roles/AgentRole.sol";

abstract contract IdentityRegistryStorage is IIdentityRegistryStorage, IRSStorage, AgentRole {
    function addIdentityToStorage(
        eaddress _userAddress,
        IIdentity _identity,
        euint16 _country
    ) external override onlyAgent {
        require(address(_identities[_userAddress].identityContract) == address(0), "address stored already");
        _identities[_userAddress].identityContract = _identity;
        _identities[_userAddress].investorCountry = _country;
        emit IdentityStored(_userAddress, _identity);
    }

    function modifyStoredIdentity(eaddress _userAddress, IIdentity _identity) external override onlyAgent {
        // require(_userAddress != address(0) && address(_identity) != address(0), "invalid argument - zero address");
        require(address(_identities[_userAddress].identityContract) != address(0), "address not stored yet");
        IIdentity oldIdentity = _identities[_userAddress].identityContract;
        _identities[_userAddress].identityContract = _identity;
        emit IdentityModified(oldIdentity, _identity);
    }

    function modifyStoredInvestorCountry(eaddress _userAddress, euint16 _country) external override onlyAgent {
        // require(_userAddress != address(0), "invalid argument - zero address");
        require(address(_identities[_userAddress].identityContract) != address(0), "address not stored yet");
        _identities[_userAddress].investorCountry = _country;
        emit CountryModified(_userAddress, _country);
    }

    function removeIdentityFromStorage(eaddress _userAddress) external override onlyAgent {
        // require(_userAddress != address(0), "invalid argument - zero address");
        require(address(_identities[_userAddress].identityContract) != address(0), "address not stored yet");
        IIdentity oldIdentity = _identities[_userAddress].identityContract;
        delete _identities[_userAddress];
        emit IdentityUnstored(_userAddress, oldIdentity);
    }

    function bindIdentityRegistry(address _identityRegistry) external override {
        // TODO
        // require(_identityRegistry != address(0), "invalid argument - zero address");
        require(_identityRegistries.length < 300, "cannot bind more than 300 IR to 1 IRS");
        // TODO
        // addAgent(_identityRegistry);
        _identityRegistries.push(_identityRegistry);
        emit IdentityRegistryBound(_identityRegistry);
    }

    function unbindIdentityRegistry(address _identityRegistry) external override {
        require(_identityRegistry != address(0), "invalid argument - zero address");
        require(_identityRegistries.length > 0, "identity registry is not stored");
        uint256 length = _identityRegistries.length;
        for (uint256 i = 0; i < length; i++) {
            // TODO
            // if (_identityRegistries[i] == _identityRegistry) {
            //     _identityRegistries[i] = _identityRegistries[length - 1];
            //     _identityRegistries.pop();
            //     break;
            // }
        }
        // TODO
        // removeAgent(_identityRegistry);
        emit IdentityRegistryUnbound(_identityRegistry);
    }

    function linkedIdentityRegistries() external view override returns (address[] memory) {
        return _identityRegistries;
    }

    function storedIdentity(eaddress _userAddress) external view override onlyOwner returns (IIdentity) {
        return _identities[_userAddress].identityContract;
    }

    function storedInvestorCountry(eaddress _userAddress) external view override onlyOwner returns (euint16) {
        return _identities[_userAddress].investorCountry;
    }
}
