// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "../roles/AgentRole.sol";
import "./ICompliance.sol";
import "../token/IToken.sol";

abstract contract Compliance is AgentRole, ICompliance {
    /// Mapping between agents and their statuses
    mapping(address => bool) private _tokenAgentsList;

    /// Mapping of tokens linked to the compliance contract
    IToken public tokenBound;

    bool waitForUpdate = false;

    /**
     * @dev Throws if called by any address that is not a token bound to the compliance.
     */
    modifier onlyToken() {
        require(_isToken(), "error : this address is not a token bound to the compliance contract");
        _;
    }

    /**
     * @dev Throws if called by any address that is not owner of compliance or agent of the token.
     */
    modifier onlyAdmin() {
        require(
            owner() == msg.sender || (AgentRole(address(tokenBound))).isAgent(msg.sender),
            "can be called only by Admin address"
        );
        _;
    }

    /**
     *  @dev See {ICompliance-addTokenAgent}.
     *  this function is deprecated, but still implemented to avoid breaking interfaces
     */
    function addTokenAgent(address _agentAddress) external override onlyOwner {
        require(!_tokenAgentsList[_agentAddress], "This Agent is already registered");
        _tokenAgentsList[_agentAddress] = true;
        emit TokenAgentAdded(_agentAddress);
    }

    /**
     *  @dev See {ICompliance-isTokenAgent}.
     */
    function removeTokenAgent(address _agentAddress) external override onlyOwner {
        require(_tokenAgentsList[_agentAddress], "This Agent is not registered yet");
        _tokenAgentsList[_agentAddress] = false;
        emit TokenAgentRemoved(_agentAddress);
    }

    /**
     *  @dev See {ICompliance-bindToken}.
     */
    function bindToken(address _token) external override {
        require(
            owner() == msg.sender || (address(tokenBound) == address(0) && msg.sender == _token),
            "only owner or token can call"
        );
        tokenBound = IToken(_token);
        emit TokenBound(_token);
    }

    /**
     *  @dev See {ICompliance-unbindToken}.
     */
    function unbindToken(address _token) external override {
        require(owner() == msg.sender || msg.sender == _token, "only owner or token can call");
        require(_token == address(tokenBound), "This token is not bound");
        delete tokenBound;
        emit TokenUnbound(_token);
    }

    /**
     *  @dev See {ICompliance-isTokenAgent}.
     */
    function isTokenAgent(address _agentAddress) public view override returns (bool) {
        if (!_tokenAgentsList[_agentAddress] && !(AgentRole(address(tokenBound))).isAgent(_agentAddress)) {
            return false;
        }
        return true;
    }

    /**
     *  @dev See {ICompliance-isTokenBound}.
     */
    function isTokenBound(address _token) public view override returns (bool) {
        if (_token != address(tokenBound)) {
            return false;
        }
        return true;
    }

    /**
     *  @dev Returns true if the sender corresponds to a token that is bound with the Compliance contract
     */
    function _isToken() internal view returns (bool) {
        return isTokenBound(msg.sender);
    }

    /**
     *  @dev Returns the ONCHAINID (Identity) of the _userAddress
     *  @param _userAddress Address of the wallet
     *  internal function, can be called only from the functions of the Compliance smart contract
     */
    function _getIdentity(address _userAddress) internal view returns (address) {
        return address(tokenBound.identityRegistry().identity(_userAddress));
    }

    // /**
    //  *  @dev Returns the country of residence of the _userAddress
    //  *  @param _userAddress Address of the wallet
    //  *  internal function, can be called only from the functions of the Compliance smart contract
    //  */
    function _getCountry(address _userAddress) internal view returns (uint16) {
        return tokenBound.identityRegistry().investorCountry(_userAddress);
    }

    function transferred(eaddress, eaddress, euint32) external virtual override {
        waitForUpdate = true;
    }

    /**
     *  @dev See {ICompliance-created}.
     */
    // solhint-disable-next-line no-empty-blocks
    function created(address _to, uint256 _value) external virtual override {
        waitForUpdate = true;
    }

    /**
     *  @dev See {ICompliance-destroyed}.
     */
    // solhint-disable-next-line no-empty-blocks
    function destroyed(address _from, uint256 _value) external override {}

    /**
     *  @dev See {ICompliance-canTransfer}.
     */
    function canTransfer(address /*_from*/, address /*_to*/, uint256 /*_value*/) external view override returns (bool) {
        return !waitForUpdate;
    }
}
