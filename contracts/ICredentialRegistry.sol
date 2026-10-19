// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICredentialRegistry
 * @dev Interface for the hybrid ERC-1155 credential registry
 * @notice Defines the core functionality for managing educational credentials
 */
interface ICredentialRegistry {
    // Enums
    enum CredentialCategory {
        DEGREE,           // Unique, non-stackable (like ERC-721)
        CERTIFICATE,      // Stackable, time-bound
        BADGE,           // Stackable, permanent
        MICROCREDENTIAL  // Stackable, combinable for pathways
    }

    // Structs
    struct CredentialType {
        CredentialCategory category;
        string name;
        bool requiresUniqueInstance;
        uint256 maxStack;           // 0 = unlimited
        uint256 validityPeriod;     // 0 = permanent
        uint256[] prerequisites;    // Required credentials
        uint256[] combinesWith;     // For stackable pathways
        address issuer;
        bool active;
    }

    struct UniqueInstance {
        uint256 typeId;
        uint256 issuanceDate;
        uint256 expiryDate;
        address issuer;
        address learner;
        bytes32 dataHash;           // IPFS hash
        bytes32 commitmentHash;     // ZK commitment
        bool revoked;
    }

    struct StackDefinition {
        string name;
        uint256[] requiredCredentials;
        uint256[] optionalCredentials;
        uint256 minOptional;
        uint256 rewardCredentialType;
        bool autoIssue;
    }

    // Events
    event CredentialTypeCreated(uint256 indexed typeId, string name, CredentialCategory category);
    event UniqueCredentialIssued(uint256 indexed instanceId, address indexed learner, uint256 typeId);
    event StackableCredentialIssued(address indexed learner, uint256 indexed typeId, uint256 amount);
    event StackCompleted(address indexed learner, uint256 indexed stackId);
    event CredentialRevoked(uint256 indexed instanceId);
    event CredentialTransferred(address indexed from, address indexed to, uint256 indexed typeId, uint256 amount);

    // Core Functions
    function createCredentialType(
        CredentialCategory category,
        string memory name,
        bool requiresUniqueInstance,
        uint256 maxStack,
        uint256 validityPeriod,
        uint256[] memory prerequisites,
        uint256[] memory combinesWith
    ) external returns (uint256);

    function issueCredential(
        address to,
        uint256 typeId,
        uint256 amount,
        bytes memory data
    ) external returns (uint256);

    function batchIssueCredentials(
        address[] memory recipients,
        uint256[] memory typeIds,
        uint256[] memory amounts,
        bytes[] memory data
    ) external;

    function revokeCredential(uint256 instanceId) external;

    function createStackDefinition(
        string memory name,
        uint256[] memory requiredCredentials,
        uint256[] memory optionalCredentials,
        uint256 minOptional,
        uint256 rewardCredentialType,
        bool autoIssue
    ) external returns (uint256);

    function claimStackReward(uint256 stackId) external;

    // View Functions
    function getCredentialType(uint256 typeId) external view returns (CredentialType memory);
    function getUniqueInstance(uint256 instanceId) external view returns (UniqueInstance memory);
    function getStackDefinition(uint256 stackId) external view returns (StackDefinition memory);
    function getLearnerCredentials(address learner) external view returns (uint256[] memory);
    function isStackComplete(address learner, uint256 stackId) external view returns (bool);
    function verifyCredential(address learner, uint256 typeId) external returns (bool);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
}