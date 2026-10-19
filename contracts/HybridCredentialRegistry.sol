// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ICredentialRegistry.sol";

/**
 * @title HybridCredentialRegistry
 * @dev Hybrid ERC-1155 implementation for educational credentials
 * @notice Supports both unique (NFT-like) and stackable credentials with privacy features
 */
contract HybridCredentialRegistry is 
    ICredentialRegistry, 
    ERC1155, 
    AccessControl, 
    Pausable, 
    ReentrancyGuard 
{
    using Counters for Counters.Counter;

    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    // Counters for unique IDs
    Counters.Counter private _typeIdCounter;
    Counters.Counter private _instanceIdCounter;
    Counters.Counter private _stackIdCounter;

    // Mappings for credential data
    mapping(uint256 => CredentialType) public credentialTypes;
    mapping(uint256 => UniqueInstance) public uniqueInstances;
    mapping(uint256 => StackDefinition) public stackDefinitions;
    mapping(uint256 => mapping(string => string)) public instanceAttributes;
    
    // Learner tracking
    mapping(address => uint256[]) public learnerUniqueCredentials;
    mapping(address => mapping(uint256 => uint256[])) public learnerStackProgress;
    
    // Verification tracking
    mapping(address => mapping(uint256 => uint256)) public lastVerification;
    mapping(uint256 => uint256) public verificationCount;

    /**
     * @dev Constructor initializes ERC1155 with base URI and sets up admin role
     * @param uri Base URI for token metadata
     * @param admin Address to grant admin roles (use msg.sender if not deploying with CREATE2)
     */
    constructor(string memory uri, address admin) ERC1155(uri) {
        address adminAddress = admin == address(0) ? msg.sender : admin;
        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, adminAddress);
    }

    /**
     * @dev Creates a new credential type that can be issued
     * @param category The category of credential (DEGREE, CERTIFICATE, BADGE, MICROCREDENTIAL)
     * @param name Human-readable name for the credential type
     * @param requiresUniqueInstance Whether each issuance should be unique (like NFT)
     * @param maxStack Maximum number that can be held (0 = unlimited)
     * @param validityPeriod How long the credential is valid in seconds (0 = permanent)
     * @param prerequisites Array of credential type IDs required before issuance
     * @param combinesWith Array of credential type IDs this can combine with
     * @return typeId The ID of the newly created credential type
     */
    function createCredentialType(
        CredentialCategory category,
        string memory name,
        bool requiresUniqueInstance,
        uint256 maxStack,
        uint256 validityPeriod,
        uint256[] memory prerequisites,
        uint256[] memory combinesWith
    ) external override onlyRole(ADMIN_ROLE) returns (uint256) {
        uint256 typeId = _typeIdCounter.current();
        _typeIdCounter.increment();

        credentialTypes[typeId] = CredentialType({
            category: category,
            name: name,
            requiresUniqueInstance: requiresUniqueInstance,
            maxStack: maxStack,
            validityPeriod: validityPeriod,
            prerequisites: prerequisites,
            combinesWith: combinesWith,
            issuer: msg.sender,
            active: true
        });

        emit CredentialTypeCreated(typeId, name, category);
        return typeId;
    }

    /**
     * @dev Issues a credential to a learner
     * @param to Address of the credential recipient
     * @param typeId ID of the credential type to issue
     * @param amount Number of credentials to issue (must be 1 for unique instances)
     * @param data Additional data containing IPFS hash and ZK commitment
     * @return instanceId For unique credentials, returns the instance ID; otherwise returns typeId
     */
    function issueCredential(
        address to,
        uint256 typeId,
        uint256 amount,
        bytes memory data
    ) public override onlyRole(ISSUER_ROLE) whenNotPaused nonReentrant returns (uint256) {
        CredentialType memory credType = credentialTypes[typeId];
        require(credType.active, "Credential type not active");
        require(
            msg.sender == credType.issuer || hasRole(ADMIN_ROLE, msg.sender), 
            "Not authorized issuer"
        );
        
        // Check prerequisites
        _checkPrerequisites(to, credType.prerequisites);

        if (credType.requiresUniqueInstance) {
            // Issue as unique instance (like ERC-721)
            require(amount == 1, "Unique credentials cannot have amount > 1");
            return _issueUniqueInstance(to, typeId, data);
        } else {
            // Issue as stackable (standard ERC-1155)
            require(
                credType.maxStack == 0 || balanceOf(to, typeId) + amount <= credType.maxStack,
                "Exceeds max stack"
            );
            _mint(to, typeId, amount, data);
            emit StackableCredentialIssued(to, typeId, amount);
            
            // Check for stack completions
            _checkStackCompletions(to);
            return typeId;
        }
    }

    /**
     * @dev Issues multiple credentials in a single transaction for gas efficiency
     * @param recipients Array of recipient addresses
     * @param typeIds Array of credential type IDs
     * @param amounts Array of amounts to issue
     * @param data Array of additional data for each credential
     */
    function batchIssueCredentials(
        address[] memory recipients,
        uint256[] memory typeIds,
        uint256[] memory amounts,
        bytes[] memory data
    ) external override onlyRole(ISSUER_ROLE) whenNotPaused {
        require(
            recipients.length == typeIds.length && 
            typeIds.length == amounts.length &&
            amounts.length == data.length,
            "Array length mismatch"
        );
        
        for (uint256 i = 0; i < recipients.length; i++) {
            issueCredential(recipients[i], typeIds[i], amounts[i], data[i]);
        }
    }

    /**
     * @dev Revokes a unique credential instance
     * @param instanceId The ID of the unique instance to revoke
     */
    function revokeCredential(uint256 instanceId) external override {
        UniqueInstance storage instance = uniqueInstances[instanceId];
        require(
            msg.sender == instance.issuer || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized to revoke"
        );
        require(!instance.revoked, "Already revoked");
        
        instance.revoked = true;
        emit CredentialRevoked(instanceId);
    }

    /**
     * @dev Creates a stack definition for combining credentials
     * @param name Name of the stack/pathway
     * @param requiredCredentials Array of credential type IDs that are mandatory
     * @param optionalCredentials Array of credential type IDs that are optional
     * @param minOptional Minimum number of optional credentials needed
     * @param rewardCredentialType Credential type ID awarded upon completion
     * @param autoIssue Whether to automatically issue reward upon completion
     * @return stackId The ID of the newly created stack definition
     */
    function createStackDefinition(
        string memory name,
        uint256[] memory requiredCredentials,
        uint256[] memory optionalCredentials,
        uint256 minOptional,
        uint256 rewardCredentialType,
        bool autoIssue
    ) external override onlyRole(ADMIN_ROLE) returns (uint256) {
        uint256 stackId = _stackIdCounter.current();
        _stackIdCounter.increment();
        
        stackDefinitions[stackId] = StackDefinition({
            name: name,
            requiredCredentials: requiredCredentials,
            optionalCredentials: optionalCredentials,
            minOptional: minOptional,
            rewardCredentialType: rewardCredentialType,
            autoIssue: autoIssue
        });
        
        return stackId;
    }

    /**
     * @dev Allows learner to manually claim a stack reward
     * @param stackId The ID of the stack to claim
     */
    function claimStackReward(uint256 stackId) external override whenNotPaused {
        require(isStackComplete(msg.sender, stackId), "Stack not complete");
        StackDefinition memory stack = stackDefinitions[stackId];
        require(balanceOf(msg.sender, stack.rewardCredentialType) == 0, "Already claimed");
        
        _mint(msg.sender, stack.rewardCredentialType, 1, "");
        emit StackCompleted(msg.sender, stackId);
    }

    /**
     * @dev Internal function to issue a unique credential instance
     */
    function _issueUniqueInstance(
        address to,
        uint256 typeId,
        bytes memory data
    ) private returns (uint256) {
        uint256 instanceId = _instanceIdCounter.current();
        _instanceIdCounter.increment();
        
        // Create unique token ID by combining type and instance
        uint256 uniqueTokenId = (typeId << 128) | instanceId;
        
        // Store instance data
        UniqueInstance storage instance = uniqueInstances[instanceId];
        instance.typeId = typeId;
        instance.issuanceDate = block.timestamp;
        instance.issuer = msg.sender;
        instance.learner = to;
        
        // Set expiry date if credential has validity period
        CredentialType memory credType = credentialTypes[typeId];
        if (credType.validityPeriod > 0) {
            instance.expiryDate = block.timestamp + credType.validityPeriod;
        }
        
        // Decode additional data if provided
        if (data.length > 0) {
            (instance.dataHash, instance.commitmentHash) = abi.decode(data, (bytes32, bytes32));
        }
        
        // Mint the unique token
        _mint(to, uniqueTokenId, 1, "");
        learnerUniqueCredentials[to].push(instanceId);
        
        emit UniqueCredentialIssued(instanceId, to, typeId);
        return instanceId;
    }

    /**
     * @dev Internal function to check if prerequisites are met
     */
    function _checkPrerequisites(address learner, uint256[] memory prerequisites) private view {
        for (uint256 i = 0; i < prerequisites.length; i++) {
            require(
                balanceOf(learner, prerequisites[i]) > 0,
                "Missing prerequisite credential"
            );
        }
    }

    /**
     * @dev Internal function to check and issue completed stack credentials
     */
    function _checkStackCompletions(address learner) private {
        uint256 stackCount = _stackIdCounter.current();
        
        for (uint256 i = 0; i < stackCount; i++) {
            StackDefinition memory stack = stackDefinitions[i];
            
            // Skip if already completed or not auto-issue
            if (!stack.autoIssue || balanceOf(learner, stack.rewardCredentialType) > 0) {
                continue;
            }
            
            // Check requirements
            if (_isStackComplete(learner, i)) {
                _mint(learner, stack.rewardCredentialType, 1, "");
                emit StackCompleted(learner, i);
            }
        }
    }

    /**
     * @dev Internal function to verify stack completion
     */
    function _isStackComplete(address learner, uint256 stackId) private view returns (bool) {
        StackDefinition memory stack = stackDefinitions[stackId];
        
        // Check required credentials
        for (uint256 i = 0; i < stack.requiredCredentials.length; i++) {
            if (balanceOf(learner, stack.requiredCredentials[i]) == 0) {
                return false;
            }
        }
        
        // Check optional credentials
        uint256 optionalCount = 0;
        for (uint256 i = 0; i < stack.optionalCredentials.length; i++) {
            if (balanceOf(learner, stack.optionalCredentials[i]) > 0) {
                optionalCount++;
            }
        }
        
        return optionalCount >= stack.minOptional;
    }

    /**
     * @dev Checks if a learner has completed a stack
     */
    function isStackComplete(address learner, uint256 stackId) public view override returns (bool) {
        return _isStackComplete(learner, stackId);
    }

    /**
     * @dev Override balanceOf from ERC1155 to satisfy interface
     */
    function balanceOf(address account, uint256 id) public view override(ERC1155, ICredentialRegistry) returns (uint256) {
        return super.balanceOf(account, id);
    }


    /**
     * @dev Verifies if a learner holds a specific credential
     */
    function verifyCredential(address learner, uint256 typeId) public override returns (bool) {
        bool hasCredential = balanceOf(learner, typeId) > 0;
        
        if (hasCredential) {
            lastVerification[learner][typeId] = block.timestamp;
            verificationCount[typeId]++;
        }
        
        return hasCredential;
    }

    /**
     * @dev Gets all unique credential instances for a learner
     */
    function getLearnerCredentials(address learner) external view override returns (uint256[] memory) {
        return learnerUniqueCredentials[learner];
    }

    /**
     * @dev Gets credential type information
     */
    function getCredentialType(uint256 typeId) external view override returns (CredentialType memory) {
        return credentialTypes[typeId];
    }

    /**
     * @dev Gets unique instance information
     */
    function getUniqueInstance(uint256 instanceId) external view override returns (UniqueInstance memory) {
        return uniqueInstances[instanceId];
    }

    /**
     * @dev Gets stack definition information
     */
    function getStackDefinition(uint256 stackId) external view override returns (StackDefinition memory) {
        return stackDefinitions[stackId];
    }

    /**
     * @dev Sets an attribute for a unique instance
     */
    function setInstanceAttribute(
        uint256 instanceId,
        string memory key,
        string memory value
    ) external {
        UniqueInstance memory instance = uniqueInstances[instanceId];
        require(
            msg.sender == instance.issuer || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        instanceAttributes[instanceId][key] = value;
    }

    /**
     * @dev Gets an attribute for a unique instance
     */
    function getInstanceAttribute(
        uint256 instanceId,
        string memory key
    ) external view returns (string memory) {
        return instanceAttributes[instanceId][key];
    }

    /**
     * @dev Override to add access control to transfers
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override(ERC1155, ICredentialRegistry) {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        
        // Check if credential is transferable
        uint256 typeId = id >> 128; // Extract type ID from token ID
        CredentialType memory credType = credentialTypes[typeId];
        
        // Degrees cannot be transferred
        require(credType.category != CredentialCategory.DEGREE, "Degrees are non-transferable");
        
        _safeTransferFrom(from, to, id, amount, data);
        emit CredentialTransferred(from, to, typeId, amount);
    }

    /**
     * @dev Pause contract functionality in case of emergency
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract functionality
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Required override for AccessControl
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}