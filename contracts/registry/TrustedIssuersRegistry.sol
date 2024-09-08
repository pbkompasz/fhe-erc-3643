// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "./interfaces/ITrustedIssuersRegistry.sol";
import "../identity/interfaces/IClaimIssuer.sol";
import "./storage/TrustedIssuerStorage.sol";

abstract contract TrustedIssuersRegistry is ITrustedIssuersRegistry, TrustedIssuerStorage {
    function addTrustedIssuer(IClaimIssuer _trustedIssuer, euint4[] calldata _claimTopics) external {
        require(address(_trustedIssuer) != address(0), "invalid argument - zero address");
        require(_trustedIssuerClaimTopics[address(_trustedIssuer)].length == 0, "trusted Issuer already exists");

        _trustedIssuers.push(_trustedIssuer);
        _trustedIssuerClaimTopics[address(_trustedIssuer)] = _claimTopics;
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            _claimTopicsToTrustedIssuers[_claimTopics[i]].push(_trustedIssuer);
        }
        emit TrustedIssuerAdded(_trustedIssuer, _claimTopics);
    }

    function removeTrustedIssuer(IClaimIssuer _trustedIssuer) external {
        require(address(_trustedIssuer) != address(0), "invalid argument - zero address");
        require(_trustedIssuerClaimTopics[address(_trustedIssuer)].length != 0, "NOT a trusted issuer");
        uint256 length = _trustedIssuers.length;
        for (uint256 i = 0; i < length; i++) {
            if (_trustedIssuers[i] == _trustedIssuer) {
                _trustedIssuers[i] = _trustedIssuers[length - 1];
                _trustedIssuers.pop();
                break;
            }
        }
        // TODO Remove topic for removed trusted issuer
        // for (
        //     uint256 claimTopicIndex = 0;
        //     claimTopicIndex < _trustedIssuerClaimTopics[address(_trustedIssuer)].length;
        //     claimTopicIndex++
        // ) {
        //     euint4 claimTopic = _trustedIssuerClaimTopics[address(_trustedIssuer)][claimTopicIndex];
        //     uint256 topicsLength = _claimTopicsToTrustedIssuers[claimTopic].length;
        //     for (uint256 i = 0; i < topicsLength; i++) {
        //         if (_claimTopicsToTrustedIssuers[claimTopic][i] == _trustedIssuer) {
        //             _claimTopicsToTrustedIssuers[claimTopic][i] = _claimTopicsToTrustedIssuers[claimTopic][
        //                 topicsLength - 1
        //             ];
        //             _claimTopicsToTrustedIssuers[claimTopic].pop();
        //             break;
        //         }
        //     }
        // }
        // delete _trustedIssuerClaimTopics[address(_trustedIssuer)];
        emit TrustedIssuerRemoved(_trustedIssuer);
    }
    // TODO Check
    function updateIssuerClaimTopics(IClaimIssuer _trustedIssuer, euint4[] calldata _claimTopics) external {
        require(address(_trustedIssuer) != address(0), "invalid argument - zero address");
        require(_trustedIssuerClaimTopics[address(_trustedIssuer)].length != 0, "NOT a trusted issuer");
        require(_claimTopics.length > 0, "claim topics cannot be empty");

        for (uint256 i = 0; i < _trustedIssuerClaimTopics[address(_trustedIssuer)].length; i++) {
            euint4 claimTopic = _trustedIssuerClaimTopics[address(_trustedIssuer)][i];
            uint256 topicsLength = _claimTopicsToTrustedIssuers[claimTopic].length;
            for (uint256 j = 0; j < topicsLength; j++) {
                if (_claimTopicsToTrustedIssuers[claimTopic][j] == _trustedIssuer) {
                    _claimTopicsToTrustedIssuers[claimTopic][j] = _claimTopicsToTrustedIssuers[claimTopic][
                        topicsLength - 1
                    ];
                    _claimTopicsToTrustedIssuers[claimTopic].pop();
                    break;
                }
            }
        }
        _trustedIssuerClaimTopics[address(_trustedIssuer)] = _claimTopics;
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            _claimTopicsToTrustedIssuers[_claimTopics[i]].push(_trustedIssuer);
        }
        emit ClaimTopicsUpdated(_trustedIssuer, _claimTopics);
    }

    function getTrustedIssuers() external view returns (IClaimIssuer[] memory) {
        return _trustedIssuers;
    }
    function isTrustedIssuer(address _issuer) external view returns (bool) {
        if (_trustedIssuerClaimTopics[_issuer].length > 0) {
            return true;
        }
        return false;
    }
    function getTrustedIssuerClaimTopics(IClaimIssuer _trustedIssuer) external view returns (euint4[] memory) {
        require(_trustedIssuerClaimTopics[address(_trustedIssuer)].length != 0, "trusted Issuer doesn't exist");
        return _trustedIssuerClaimTopics[address(_trustedIssuer)];
    }

    function getTrustedIssuersForClaimTopic(euint4 claimTopic) external view returns (IClaimIssuer[] memory) {
        return _claimTopicsToTrustedIssuers[claimTopic];
    }

    // >0 true
    function hasClaimTopic(address _issuer, euint4 _claimTopic) external returns (euint32) {
        uint256 length = _trustedIssuerClaimTopics[_issuer].length;
        euint4[] memory claimTopics = _trustedIssuerClaimTopics[_issuer];
        euint32 has = TFHE.asEuint32(0);
        for (uint256 i = 0; i < length; i++) {
            ebool isEqual = TFHE.eq(claimTopics[i], _claimTopic);
            has = TFHE.add(has, TFHE.select(isEqual, TFHE.asEuint32(1), TFHE.asEuint32(0)));
        }
        return has;
    }
}
