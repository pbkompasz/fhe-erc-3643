// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "../roles/AgentRole.sol";

abstract contract KYCClaim is AgentRole {
    ebytes256 firstname;
    ebytes256 lastname;
    euint8 countryCode;
    ebytes256 email;

    bool isVerified = false;

    function _isValid() internal {}

    function submitData(
        einput firstnameEncrypted,
        einput lastnameEncrypted,
        einput countryEncrypted,
        einput emailEncrypted,
        bytes calldata inputProof
    ) external onlyOwner {
        firstname = TFHE.asEbytes256(firstnameEncrypted, inputProof);
        lastname = TFHE.asEbytes256(lastnameEncrypted, inputProof);
        countryCode = TFHE.asEuint8(countryEncrypted, inputProof);
        email = TFHE.asEbytes256(emailEncrypted, inputProof);
    }

    function verifyData() external onlyAgent {
        isVerified = true;
    }
}
