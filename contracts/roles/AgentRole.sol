// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "./IAgentRole.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract AgentRole is IAgentRole, Ownable {
    mapping(address => bool) private _agents;

    modifier onlyAgent() {
        require(isAgent(msg.sender), "AgentRole: caller does not have the Agent role");
        _;
    }

    function addAgent(address _agent) public onlyOwner {
        require(_agent != address(0), "AgentRole: zero address");
        _agents[_agent] = true;
        emit AgentAdded(_agent);
    }

    function removeAgent(address _agent) public onlyOwner {
        require(_agent != address(0), "AgentRole: zero address");
        require(_agents[_agent], "AgentRole: cannot remove not agent");
        _agents[_agent] = false;
        emit AgentRemoved(_agent);
        (_agent);
    }

    function isAgent(address _agent) public view returns (bool) {
        require(_agent != address(0), "AgentRole: zero address");
        return _agents[_agent];
    }
}
