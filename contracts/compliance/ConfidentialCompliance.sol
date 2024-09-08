// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "../roles/AgentRole.sol";
import "../token/IToken.sol";
import "./Compliance.sol";

abstract contract ConfidentialCompliance is Compliance {
    /// Mapping between agents and their statuses
    mapping(address => bool) private _tokenAgentsList;

    ebool waitForUpdateEncrypted = TFHE.asEbool(false);

    /**
     *  @dev Returns the ONCHAINID (Identity) of the _userAddress
     *  @param _userAddress Address of the wallet
     *  internal function, can be called only from the functions of the Compliance smart contract
     */
    function _getIdentity(eaddress _userAddress) internal view returns (address) {
        return address(tokenBound.identityRegistry().identity(_userAddress));
    }

    // /**
    //  *  @dev Returns the country of residence of the _userAddress
    //  *  @param _userAddress Address of the wallet
    //  *  internal function, can be called only from the functions of the Compliance smart contract
    //  */
    function _getCountry(eaddress _userAddress) internal view returns (euint16) {
        return tokenBound.identityRegistry().investorCountry(_userAddress);
    }

    function transferred(eaddress _from, eaddress _to, euint32 _value) external override {
        waitForUpdateEncrypted = TFHE.asEbool(true);
    }

    /**
     *  @dev See {ICompliance-created}.
     */
    // solhint-disable-next-line no-empty-blocks
    function created(eaddress _to, euint32 _value) external override {
        waitForUpdateEncrypted = TFHE.asEbool(true);
    }

    /**
     *  @dev See {ICompliance-destroyed}.
     */
    // solhint-disable-next-line no-empty-blocks
    function destroyed(eaddress _from, euint32 _value) external override {}

    /**
     *  @dev See {ICompliance-canTransfer}.
     */
    function canTransfer(eaddress /*_from*/, eaddress /*_to*/, euint32 /*_value*/) external override returns (ebool) {
        return TFHE.not(waitForUpdateEncrypted);
    }
}
