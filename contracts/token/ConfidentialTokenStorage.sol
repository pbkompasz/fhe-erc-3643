// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "../compliance/ICompliance.sol";
import "../registry/interfaces/IIdentityRegistry.sol";

contract ConfidentialTokenStorage {
    mapping(eaddress => euint32) internal _balancesEncrypted;
    mapping(eaddress => mapping(eaddress => euint32)) internal _allowancesEncrypted;
    euint8 internal _totalSupplyConfidential;

    ebytes256 internal _tokenNameEncrypted;
    ebytes256 internal _tokenSymbolEncrypted;
    euint8 internal _tokenDecimalsEncrypted;
    ebool internal _tokenPausedEncrypted;

    mapping(eaddress => ebool) internal _frozenEncrypted;
    mapping(eaddress => euint8) internal _frozenTokensEncrypted;
}
