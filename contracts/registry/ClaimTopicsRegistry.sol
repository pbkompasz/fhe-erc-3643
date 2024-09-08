// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "./interfaces/IClaimTopicsRegistry.sol";
import "./storage/ClaimTopicStorage.sol";

abstract contract ClaimTopicsRegistry is IClaimTopicsRegistry, ClaimTopicStorage {
    /**
     *  @dev See {IClaimTopicsRegistry-addClaimTopic}.
     */
    function addClaimTopic(
        euint4 _claimTopic // onlyOwner
    ) external override {
        uint256 length = _claimTopics.length;
        require(length < 15, "cannot require more than 15 topics");
        euint32 pos;
        for (uint256 i = 0; i < 15; i++) {
            ebool isEqual = TFHE.eq(_claimTopics[i], _claimTopic);
            pos = TFHE.select(isEqual, TFHE.asEuint32(errorPos), TFHE.asEuint32(currPos));
        }
        // TODO
        // decrypt(pos) emit Update soon ...
        // _claimTopics[pos] = _claimTopic;
        // emit ClaimTopicAdded(_claimTopic);
    }

    /**
     *  @dev See {IClaimTopicsRegistry-removeClaimTopic}.
     */
    function removeClaimTopic(
        euint4 _claimTopic // onlyOwner
    ) external override {
        euint32 pos;
        for (uint256 i = 0; i < 15; i++) {
            ebool isEqual = TFHE.eq(_claimTopics[i], _claimTopic);
            pos = TFHE.select(isEqual, TFHE.asEuint32(errorPos), TFHE.asEuint32(currPos));
            // TODO decrypt pos, check if > 0, override w/ -1 for removal, decrease currPos
            // emit ClaimTopicRemoved(_claimTopic);
        }
    }

    /**
     *  @dev See {IClaimTopicsRegistry-getClaimTopics}.
     */
    function getClaimTopics() external view override returns (euint4[] memory) {
        return _claimTopics;
    }
}
