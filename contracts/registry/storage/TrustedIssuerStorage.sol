pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "../../erc-734+735/interfaces/IClaimIssuer.sol";

contract TrustedIssuerStorage {
    /// @dev Array containing all TrustedIssuers identity contract address.
    IClaimIssuer[] internal _trustedIssuers;

    /// @dev Mapping between a trusted issuer address and its corresponding claimTopics.
    mapping(address => euint4[]) internal _trustedIssuerClaimTopics;

    /// @dev Mapping between a claim topic and the allowed trusted issuers for it.
    mapping(euint4 => IClaimIssuer[]) internal _claimTopicsToTrustedIssuers;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[49] private __gap;
}
