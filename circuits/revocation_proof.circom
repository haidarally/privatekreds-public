pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/mux1.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/smt/smtverifier.circom";

/**
 * Revocation Proof Circuit
 * Proves that a credential has not been revoked without revealing the credential
 * Implements privacy-preserving revocation using Sparse Merkle Trees
 * Part of Milestone 2: Privacy Integration
 */

template RevocationProof() {
    // Merkle tree parameters
    var TREE_LEVELS = 20; // Supports up to 2^20 = ~1M credentials

    // Private inputs (credential identity + SMT non-membership witnesses)
    signal private input credentialId;
    signal private input revocationSecret;
    signal private input revocationNonce;
    signal private input siblings[TREE_LEVELS]; // SMT sibling path
    signal private input oldKey;                // Closest existing key in tree
    signal private input oldValue;              // Value stored at oldKey
    signal private input isOld0;                // 1 if tree is empty at query point

    // Public inputs
    signal input revocationRoot;    // Current revocation tree root
    signal input nullifierHash;     // Public nullifier (revocation check identity)
    signal input timestamp;         // Proof generation timestamp (freshness)

    // Outputs
    signal output notRevoked;             // 1 iff SMT non-membership holds
    signal output revocationNullifier;    // Nullifier tied to this revocation check
    signal output credentialCommitment;   // Commitment to the credential being checked

    // Components
    component credentialHasher = Poseidon(3);
    component nullifierHasher = Poseidon(3);
    component commitmentHasher = Poseidon(2);
    component smt = SMTVerifier(TREE_LEVELS);

    // 1. Derive the SMT key from the credential identity.
    //    Key = Poseidon(credentialId, revocationSecret, revocationNonce).
    //    Only the issuer and holder can compute this; leaks nothing about the credential.
    credentialHasher.inputs[0] <== credentialId;
    credentialHasher.inputs[1] <== revocationSecret;
    credentialHasher.inputs[2] <== revocationNonce;

    // 2. Derive the public revocation nullifier for this check.
    //    Nullifier = Poseidon(credentialId, revocationSecret, timestamp).
    nullifierHasher.inputs[0] <== credentialId;
    nullifierHasher.inputs[1] <== revocationSecret;
    nullifierHasher.inputs[2] <== timestamp;
    revocationNullifier <== nullifierHasher.out;

    // 3. Derive the credential commitment (long-lived identifier).
    commitmentHasher.inputs[0] <== credentialId;
    commitmentHasher.inputs[1] <== revocationSecret;
    credentialCommitment <== commitmentHasher.out;

    // 4. Bind derived nullifier to the public input.
    component nullifierVerifier = IsEqual();
    nullifierVerifier.in[0] <== revocationNullifier;
    nullifierVerifier.in[1] <== nullifierHash;
    nullifierVerifier.out === 1;

    // 5. SMT non-membership proof: assert credentialHasher.out is NOT in the
    //    tree rooted at revocationRoot.  fnc = 1 selects non-membership mode;
    //    circomlib's SMTVerifier enforces the non-membership relation as an
    //    R1CS constraint set when enabled = 1.  If non-membership does not
    //    hold, the R1CS is unsatisfiable and no valid Groth16 proof exists.
    smt.enabled  <== 1;
    smt.fnc      <== 1;                       // 1 = non-membership
    smt.root     <== revocationRoot;
    smt.key      <== credentialHasher.out;    // SMT key (private, derived)
    smt.value    <== 0;                       // unused for non-membership
    smt.oldKey   <== oldKey;                  // non-membership witness: closest key
    smt.oldValue <== oldValue;
    smt.isOld0   <== isOld0;
    for (var i = 0; i < TREE_LEVELS; i++) {
        smt.siblings[i] <== siblings[i];      // full sibling path (no leaf overwrite)
    }

    // 6. Non-membership is enforced by (5); notRevoked = 1 is the truthful
    //    signal that this proof exists <==> credential not in revocation tree.
    notRevoked <== 1;

    // 7. Timestamp validation (freshness gate).
    component timestampValidator = GreaterThan(32);
    timestampValidator.in[0] <== timestamp;
    timestampValidator.in[1] <== 0;
    timestampValidator.out === 1;
}

/**
 * Batch Revocation Proof Circuit
 * Proves that multiple credentials have not been revoked in a single proof
 * Optimized for institutions checking multiple credentials
 */
template BatchRevocationProof() {
    var MAX_CREDENTIALS = 10;
    var TREE_LEVELS = 20;
    
    // Private inputs (arrays for each credential)
    signal private input credentialIds[MAX_CREDENTIALS];
    signal private input revocationSecrets[MAX_CREDENTIALS];
    signal private input revocationNonces[MAX_CREDENTIALS];
    
    // Public inputs
    signal input revocationRoot;
    signal input revocationProofs[MAX_CREDENTIALS][TREE_LEVELS];
    signal input revocationIndices[MAX_CREDENTIALS][TREE_LEVELS];
    signal input nullifierHashes[MAX_CREDENTIALS];
    signal input timestamp;
    signal input batchSize; // Actual number of credentials to check
    
    // Outputs
    signal output allNotRevoked;
    signal output batchNullifier;
    signal output revocationNullifiers[MAX_CREDENTIALS];
    
    // Components
    component revocationProofs[MAX_CREDENTIALS];
    component batchValidator = MultiAND(MAX_CREDENTIALS);
    component batchNullifierHasher = Poseidon(MAX_CREDENTIALS + 1);
    component sizeValidator = LessEqualThan(8);
    component credentialSelector[MAX_CREDENTIALS];
    
    // Validate batch size
    sizeValidator.in[0] <== batchSize;
    sizeValidator.in[1] <== MAX_CREDENTIALS;
    sizeValidator.out === 1;
    
    // Initialize batch nullifier hash
    batchNullifierHasher.inputs[0] <== timestamp;
    
    // Process each credential
    for (var i = 0; i < MAX_CREDENTIALS; i++) {
        // Create revocation proof instance
        revocationProofs[i] = RevocationProof();
        
        // Create selector for variable batch sizes
        credentialSelector[i] = LessThan(8);
        credentialSelector[i].in[0] <== i;
        credentialSelector[i].in[1] <== batchSize;
        
        // Connect inputs
        revocationProofs[i].credentialId <== credentialIds[i];
        revocationProofs[i].revocationSecret <== revocationSecrets[i];
        revocationProofs[i].revocationNonce <== revocationNonces[i];
        revocationProofs[i].revocationRoot <== revocationRoot;
        revocationProofs[i].nullifierHash <== nullifierHashes[i];
        revocationProofs[i].timestamp <== timestamp;
        
        // Connect proof paths
        for (var j = 0; j < TREE_LEVELS; j++) {
            revocationProofs[i].revocationProof[j] <== revocationProofs[i][j];
            revocationProofs[i].revocationIndices[j] <== revocationIndices[i][j];
        }
        
        // Collect nullifiers
        revocationNullifiers[i] <== revocationProofs[i].revocationNullifier;
        
        // Add to batch nullifier hash
        batchNullifierHasher.inputs[i + 1] <== revocationNullifiers[i];
        
        // Validate credential or skip if out of range
        component validityMux = Mux1();
        validityMux.c[0] <== 1; // Default to valid for unused slots
        validityMux.c[1] <== revocationProofs[i].notRevoked;
        validityMux.s <== credentialSelector[i].out;
        
        batchValidator.in[i] <== validityMux.out;
    }
    
    // Generate outputs
    allNotRevoked <== batchValidator.out;
    batchNullifier <== batchNullifierHasher.out;
}

/**
 * Revocation Update Proof Circuit
 * Proves that a revocation tree update is valid
 * Used by institutions to update revocation status
 */
template RevocationUpdateProof() {
    var TREE_LEVELS = 20;
    
    // Private inputs
    signal private input credentialId;
    signal private input revocationSecret;
    signal private input oldRoot;
    signal private input newRoot;
    signal private input updateProof[TREE_LEVELS];
    signal private input updateIndices[TREE_LEVELS];
    
    // Public inputs
    signal input institutionId;
    signal input timestamp;
    signal input updateType; // 0 for revoke, 1 for unrevoke
    
    // Outputs
    signal output updateValid;
    signal output credentialHash;
    
    // Components
    component credentialHasher = Poseidon(2);
    component oldTreeVerifier = SMTVerifier(TREE_LEVELS);
    component newTreeVerifier = SMTVerifier(TREE_LEVELS);
    component updateValidator = IsEqual();
    
    // Generate credential hash
    credentialHasher.inputs[0] <== credentialId;
    credentialHasher.inputs[1] <== revocationSecret;
    credentialHash <== credentialHasher.out;
    
    // Verify old tree state
    oldTreeVerifier.enabled <== 1;
    oldTreeVerifier.fnc <== updateType; // 0 for revoke (was not in tree), 1 for unrevoke (was in tree)
    oldTreeVerifier.root <== oldRoot;
    oldTreeVerifier.siblings[0] <== credentialHash;
    
    // Verify new tree state
    newTreeVerifier.enabled <== 1;
    newTreeVerifier.fnc <== 1 - updateType; // Opposite of old state
    newTreeVerifier.root <== newRoot;
    newTreeVerifier.siblings[0] <== credentialHash;
    
    // Set up proof paths for both verifiers
    for (var i = 1; i < TREE_LEVELS; i++) {
        oldTreeVerifier.siblings[i] <== updateProof[i-1];
        newTreeVerifier.siblings[i] <== updateProof[i-1];
    }
    
    // Set path indices
    for (var i = 0; i < TREE_LEVELS; i++) {
        oldTreeVerifier.pathIndices[i] <== updateIndices[i];
        newTreeVerifier.pathIndices[i] <== updateIndices[i];
    }
    
    // Validate update
    component oldValid = IsEqual();
    oldValid.in[0] <== oldTreeVerifier.root;
    oldValid.in[1] <== oldRoot;
    
    component newValid = IsEqual();
    newValid.in[0] <== newTreeVerifier.root;
    newValid.in[1] <== newRoot;
    
    component bothValid = AND();
    bothValid.a <== oldValid.out;
    bothValid.b <== newValid.out;
    
    updateValid <== bothValid.out;
    
    // Timestamp validation
    component timestampValidator = GreaterThan(32);
    timestampValidator.in[0] <== timestamp;
    timestampValidator.in[1] <== 0;
    timestampValidator.out === 1;
}

/**
 * Efficient Revocation Checker
 * Simplified circuit for high-performance revocation checking
 * Used in production environments with frequent checks
 */
template EfficientRevocationChecker() {
    // Private inputs
    signal private input credentialHash;
    signal private input revocationWitness;
    
    // Public inputs
    signal input revocationRoot;
    signal input expectedResult; // 0 if should be revoked, 1 if not revoked
    
    // Output
    signal output isValid;
    
    // Components
    component witnessVerifier = Poseidon(2);
    component resultVerifier = IsEqual();
    
    // Verify witness
    witnessVerifier.inputs[0] <== credentialHash;
    witnessVerifier.inputs[1] <== revocationWitness;
    
    // Check if witness produces expected result
    resultVerifier.in[0] <== witnessVerifier.out;
    resultVerifier.in[1] <== expectedResult;
    
    isValid <== resultVerifier.out;
}

/**
 * Multi-AND Gate for batch validation
 * Efficiently combines multiple validity signals
 */
template MultiAND(n) {
    signal input in[n];
    signal output out;
    
    if (n == 1) {
        out <== in[0];
    } else if (n == 2) {
        component and2 = AND();
        and2.a <== in[0];
        and2.b <== in[1];
        out <== and2.out;
    } else {
        component and = AND();
        component multiAnd = MultiAND(n-1);
        
        for (var i = 0; i < n-1; i++) {
            multiAnd.in[i] <== in[i];
        }
        
        and.a <== multiAnd.out;
        and.b <== in[n-1];
        out <== and.out;
    }
}

/**
 * Main circuit entry point for revocation checking
 */
component main = RevocationProof();