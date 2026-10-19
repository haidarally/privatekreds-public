// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ZKVerifier.sol";
import "./ICredentialRegistry.sol";

/**
 * @title SelectiveDisclosure
 * @dev Manages selective disclosure of credential attributes using zero-knowledge proofs
 * @notice Allows learners to prove credential properties without revealing full details
 */
contract SelectiveDisclosure is AccessControl, ReentrancyGuard {
    // Role for disclosure managers
    bytes32 public constant DISCLOSURE_MANAGER_ROLE = keccak256("DISCLOSURE_MANAGER_ROLE");

    // References to other contracts
    ICredentialRegistry public credentialRegistry;
    ZKVerifier public zkVerifier;

    // Disclosure request structure
    struct DisclosureRequest {
        address requester;
        address learner;
        uint256 credentialTypeId;
        string[] requestedAttributes;
        uint256 expiryTime;
        bool fulfilled;
        bytes32 proofHash;
    }

    // Disclosure template for common verification scenarios
    struct DisclosureTemplate {
        string name;
        string[] attributes;
        uint256 proofType;
        bool active;
    }

    // Mappings
    mapping(uint256 => DisclosureRequest) public disclosureRequests;
    mapping(uint256 => DisclosureTemplate) public disclosureTemplates;
    mapping(address => uint256[]) public learnerRequests;
    mapping(address => uint256[]) public requesterHistory;
    mapping(bytes32 => bool) public disclosedProofs;

    // Counters
    uint256 public requestIdCounter;
    uint256 public templateIdCounter;

    // Events
    event DisclosureRequested(
        uint256 indexed requestId,
        address indexed requester,
        address indexed learner,
        uint256 credentialTypeId
    );
    event DisclosureProvided(
        uint256 indexed requestId,
        address indexed learner,
        bytes32 proofHash
    );
    event DisclosureTemplateCreated(
        uint256 indexed templateId,
        string name,
        uint256 proofType
    );
    event DisclosureRevoked(bytes32 indexed proofHash, address indexed learner);

    /**
     * @dev Constructor initializes the contract with registry and verifier addresses
     * @param _credentialRegistry Address of the credential registry contract
     * @param _zkVerifier Address of the ZK verifier contract
     */
    constructor(address _credentialRegistry, address _zkVerifier) {
        credentialRegistry = ICredentialRegistry(_credentialRegistry);
        zkVerifier = ZKVerifier(_zkVerifier);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISCLOSURE_MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev Creates a disclosure template for common verification scenarios
     * @param name Name of the template (e.g., "Employment Verification")
     * @param attributes Array of attribute names to disclose
     * @param proofType The type of ZK proof to use
     * @return templateId The ID of the created template
     */
    function createDisclosureTemplate(
        string memory name,
        string[] memory attributes,
        uint256 proofType
    ) external onlyRole(DISCLOSURE_MANAGER_ROLE) returns (uint256) {
        uint256 templateId = templateIdCounter++;
        
        disclosureTemplates[templateId] = DisclosureTemplate({
            name: name,
            attributes: attributes,
            proofType: proofType,
            active: true
        });
        
        emit DisclosureTemplateCreated(templateId, name, proofType);
        return templateId;
    }

    /**
     * @dev Requests selective disclosure of credential attributes
     * @param learner Address of the credential holder
     * @param credentialTypeId Type of credential to verify
     * @param requestedAttributes Array of attribute names requested
     * @param validityPeriod How long the request is valid (in seconds)
     * @return requestId The ID of the disclosure request
     */
    function requestDisclosure(
        address learner,
        uint256 credentialTypeId,
        string[] memory requestedAttributes,
        uint256 validityPeriod
    ) external nonReentrant returns (uint256) {
        return _requestDisclosureInternal(learner, credentialTypeId, requestedAttributes, validityPeriod);
    }

    /**
     * @dev Internal function to handle disclosure requests
     * @param learner Address of the credential holder
     * @param credentialTypeId Type of credential to verify
     * @param requestedAttributes Array of attribute names requested
     * @param validityPeriod How long the request is valid (in seconds)
     * @return requestId The ID of the disclosure request
     */
    function _requestDisclosureInternal(
        address learner,
        uint256 credentialTypeId,
        string[] memory requestedAttributes,
        uint256 validityPeriod
    ) internal returns (uint256) {
        require(learner != address(0), "Invalid learner address");
        require(validityPeriod > 0 && validityPeriod <= 30 days, "Invalid validity period");
        
        uint256 requestId = requestIdCounter++;
        
        disclosureRequests[requestId] = DisclosureRequest({
            requester: msg.sender,
            learner: learner,
            credentialTypeId: credentialTypeId,
            requestedAttributes: requestedAttributes,
            expiryTime: block.timestamp + validityPeriod,
            fulfilled: false,
            proofHash: bytes32(0)
        });
        
        learnerRequests[learner].push(requestId);
        requesterHistory[msg.sender].push(requestId);
        
        emit DisclosureRequested(requestId, msg.sender, learner, credentialTypeId);
        return requestId;
    }

    /**
     * @dev Requests disclosure using a template
     * @param learner Address of the credential holder
     * @param credentialTypeId Type of credential to verify
     * @param templateId ID of the disclosure template to use
     * @param validityPeriod How long the request is valid (in seconds)
     * @return requestId The ID of the disclosure request
     */
    function requestDisclosureWithTemplate(
        address learner,
        uint256 credentialTypeId,
        uint256 templateId,
        uint256 validityPeriod
    ) external nonReentrant returns (uint256) {
        DisclosureTemplate memory template = disclosureTemplates[templateId];
        require(template.active, "Template not active");
        
        return _requestDisclosureInternal(learner, credentialTypeId, template.attributes, validityPeriod);
    }

    /**
     * @dev Fulfills a disclosure request by providing a Groth16 proof.
     * Signature matches the snarkjs-generated verifier in ZKVerifier.sol
     * (uint[2] pA, uint[2][2] pB, uint[2] pC, uint[26] pubSignals).
     * @param requestId ID of the disclosure request
     * @param pA Groth16 proof element A
     * @param pB Groth16 proof element B
     * @param pC Groth16 proof element C
     * @param pubSignals 26 public signals (15 inputs + 11 outputs) matching vkey.json
     */
    function provideDisclosure(
        uint256 requestId,
        uint[2] calldata pA,
        uint[2][2] calldata pB,
        uint[2] calldata pC,
        uint[26] calldata pubSignals
    ) external nonReentrant {
        DisclosureRequest storage request = disclosureRequests[requestId];
        require(msg.sender == request.learner, "Not the credential holder");
        require(!request.fulfilled, "Request already fulfilled");
        require(block.timestamp <= request.expiryTime, "Request expired");

        // Verify the learner has the credential
        require(
            credentialRegistry.verifyCredential(request.learner, request.credentialTypeId),
            "Credential not found"
        );

        // Verify the Groth16 proof against the on-chain verifier
        require(
            zkVerifier.verifyProof(pA, pB, pC, pubSignals),
            "Invalid proof"
        );

        bytes32 proofHash = keccak256(abi.encodePacked(requestId, pA, pB, pC, pubSignals));

        request.fulfilled = true;
        request.proofHash = proofHash;
        disclosedProofs[proofHash] = true;

        emit DisclosureProvided(requestId, msg.sender, proofHash);
    }

    /**
     * @dev Revokes a previously provided disclosure
     * @param proofHash Hash of the proof to revoke
     */
    function revokeDisclosure(bytes32 proofHash) external {
        require(disclosedProofs[proofHash], "Proof not found");
        
        // Find the associated request
        // In production, maintain a mapping for efficiency
        disclosedProofs[proofHash] = false;
        
        emit DisclosureRevoked(proofHash, msg.sender);
    }

    /**
     * @dev Verifies if a disclosure proof is still valid
     * @param proofHash Hash of the proof to verify
     * @return isValid Whether the proof is still valid
     */
    function verifyDisclosure(bytes32 proofHash) external view returns (bool isValid) {
        return disclosedProofs[proofHash];
    }

    /**
     * @dev Gets all disclosure requests for a learner
     * @param learner Address of the learner
     * @return requestIds Array of request IDs
     */
    function getLearnerRequests(address learner) external view returns (uint256[] memory) {
        return learnerRequests[learner];
    }

    /**
     * @dev Gets all disclosure requests made by a requester
     * @param requester Address of the requester
     * @return requestIds Array of request IDs
     */
    function getRequesterHistory(address requester) external view returns (uint256[] memory) {
        return requesterHistory[requester];
    }

    /**
     * @dev Gets pending disclosure requests for a learner
     * @param learner Address of the learner
     * @return pendingRequests Array of pending request IDs
     */
    function getPendingRequests(address learner) external view returns (uint256[] memory) {
        uint256[] memory allRequests = learnerRequests[learner];
        uint256 pendingCount = 0;
        
        // Count pending requests
        for (uint256 i = 0; i < allRequests.length; i++) {
            DisclosureRequest memory request = disclosureRequests[allRequests[i]];
            if (!request.fulfilled && block.timestamp <= request.expiryTime) {
                pendingCount++;
            }
        }
        
        // Collect pending requests
        uint256[] memory pendingRequests = new uint256[](pendingCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allRequests.length; i++) {
            DisclosureRequest memory request = disclosureRequests[allRequests[i]];
            if (!request.fulfilled && block.timestamp <= request.expiryTime) {
                pendingRequests[index++] = allRequests[i];
            }
        }
        
        return pendingRequests;
    }

    /**
     * @dev Updates the credential registry address
     * @param _credentialRegistry New credential registry address
     */
    function updateCredentialRegistry(address _credentialRegistry) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(_credentialRegistry != address(0), "Invalid address");
        credentialRegistry = ICredentialRegistry(_credentialRegistry);
    }

    /**
     * @dev Updates the ZK verifier address
     * @param _zkVerifier New ZK verifier address
     */
    function updateZKVerifier(address _zkVerifier) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(_zkVerifier != address(0), "Invalid address");
        zkVerifier = ZKVerifier(_zkVerifier);
    }
}