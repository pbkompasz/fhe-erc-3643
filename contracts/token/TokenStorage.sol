// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "../compliance/ICompliance.sol";
import "../registry/interfaces/IIdentityRegistry.sol";

contract TokenStorage {
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 internal _totalSupply;

    string internal _tokenName;
    string internal _tokenSymbol;
    uint8 internal _tokenDecimals;
    address internal _tokenOnchainID;
    string internal constant _TOKEN_VERSION = "4.1.3";

    mapping(address => bool) internal _frozen;
    mapping(address => uint256) internal _frozenTokens;

    bool internal _tokenPaused = false;

    IIdentityRegistry internal _tokenIdentityRegistry;
}
