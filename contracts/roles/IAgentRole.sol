// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

interface IAgentRole {
    // events
    event AgentAdded(address indexed _agent);
    event AgentRemoved(address indexed _agent);

    // functions
    // setters
    function addAgent(address _agent) external;
    function removeAgent(address _agent) external;

    // getters
    function isAgent(address _agent) external view returns (bool);
}
