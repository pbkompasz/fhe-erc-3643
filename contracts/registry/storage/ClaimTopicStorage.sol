pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";

contract ClaimTopicStorage {
    /// @dev All required Claim Topics
    // Accepts 15 valid topics
    // Invalid topics, duplicates go at pos 15 (starting from 0)
    // This requires 1 decryption instead of one for each comparison
    euint4[] internal _claimTopics = new euint4[](16);

    uint32 currPos = 0;
    uint32 errorPos = 15;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[49] private __gap;
}
