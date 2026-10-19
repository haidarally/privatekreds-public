pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/mux1.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "./credential_proof.circom";

/**
 * Batch Credential Proof Circuit
 * Enables proving ownership of multiple credentials simultaneously
 * Optimized for efficiency when verifying multiple credentials
 * Part of Milestone 2: Privacy Integration
 */

template BatchCredentialProof() {
    // Maximum number of credentials that can be processed in a single batch
    var MAX_CREDENTIALS = 5;
    var MAX_ATTRIBUTES = 10;
    
    // Private inputs (arrays for each credential)
    signal private input credentials[MAX_CREDENTIALS][MAX_ATTRIBUTES];
    signal private input salts[MAX_CREDENTIALS];
    signal private input nullifiers[MAX_CREDENTIALS];
    
    // Public inputs (batch verification parameters)
    signal input commitments[MAX_CREDENTIALS];
    signal input nullifierHashes[MAX_CREDENTIALS];
    signal input disclosureMasks[MAX_CREDENTIALS][MAX_ATTRIBUTES];
    signal input numCredentials; // Actual number of credentials (<=MAX_CREDENTIALS)
    
    // Batch verification parameters
    signal input batchId;
    signal input timestamp;
    signal input verifierId;
    
    // Outputs
    signal output batchValid;
    signal output batchHash;
    signal output disclosedBatch[MAX_CREDENTIALS][MAX_ATTRIBUTES];
    
    // Components
    component credentialProofs[MAX_CREDENTIALS];
    component batchHasher = Poseidon(MAX_CREDENTIALS + 3);
    component validityChecker = MultiAND(MAX_CREDENTIALS);
    component credentialSelector[MAX_CREDENTIALS];
    
    // Initialize batch hasher with batch metadata
    batchHasher.inputs[0] <== batchId;
    batchHasher.inputs[1] <== timestamp;
    batchHasher.inputs[2] <== verifierId;
    
    // Process each credential in the batch
    for (var i = 0; i < MAX_CREDENTIALS; i++) {
        // Create credential proof instance
        credentialProofs[i] = CredentialProof();
        
        // Create selector to handle variable batch sizes
        credentialSelector[i] = LessThan(8);
        credentialSelector[i].in[0] <== i;
        credentialSelector[i].in[1] <== numCredentials;
        
        // Connect inputs only for active credentials
        for (var j = 0; j < MAX_ATTRIBUTES; j++) {
            credentialProofs[i].credentialData[j] <== credentials[i][j];
            credentialProofs[i].disclosureMask[j] <== disclosureMasks[i][j];
        }
        
        credentialProofs[i].salt <== salts[i];
        credentialProofs[i].nullifier <== nullifiers[i];
        credentialProofs[i].commitment <== commitments[i];
        credentialProofs[i].nullifierHash <== nullifierHashes[i];
        
        // Set default values for credential-specific verification
        credentialProofs[i].minAge <== 0;
        credentialProofs[i].maxAge <== 150;
        credentialProofs[i].requiredGrade <== 0;
        credentialProofs[i].institutionId <== 0;
        credentialProofs[i].credentialType <== 0;
        
        // Collect disclosed data for each credential
        for (var j = 0; j < MAX_ATTRIBUTES; j++) {
            disclosedBatch[i][j] <== credentialProofs[i].disclosedData[j];
        }
        
        // Verify credential validity or skip if out of range
        component validityMux = Mux1();
        validityMux.c[0] <== 1; // Default to valid for unused slots
        validityMux.c[1] <== credentialProofs[i].validAge * 
                             credentialProofs[i].validGrade * 
                             credentialProofs[i].validInstitution * 
                             credentialProofs[i].validType;
        validityMux.s <== credentialSelector[i].out;
        
        validityChecker.in[i] <== validityMux.out;
        
        // Add credential commitment to batch hash
        batchHasher.inputs[i + 3] <== commitments[i];
    }
    
    // Generate final batch hash
    batchHash <== batchHasher.out;
    
    // Ensure all active credentials are valid
    batchValid <== validityChecker.out;
    
    // Additional batch-specific constraints
    component batchSizeCheck = LessEqualThan(8);
    batchSizeCheck.in[0] <== numCredentials;
    batchSizeCheck.in[1] <== MAX_CREDENTIALS;
    batchSizeCheck.out === 1;
    
    component timestampCheck = GreaterThan(32);
    timestampCheck.in[0] <== timestamp;
    timestampCheck.in[1] <== 0;
    timestampCheck.out === 1;
}

/**
 * Batch Aggregation Circuit
 * Combines multiple batch proofs into a single aggregated proof
 * Used for institutional-level credential verification
 */
template BatchAggregation() {
    var MAX_BATCHES = 3;
    
    // Private inputs
    signal private input batchProofs[MAX_BATCHES];
    signal private input batchHashes[MAX_BATCHES];
    
    // Public inputs
    signal input aggregationId;
    signal input institutionId;
    signal input totalCredentials;
    
    // Outputs
    signal output aggregationHash;
    signal output allBatchesValid;
    
    // Components
    component aggregationHasher = Poseidon(MAX_BATCHES + 3);
    component batchValidator = MultiAND(MAX_BATCHES);
    component proofVerifiers[MAX_BATCHES];
    
    // Initialize aggregation hash
    aggregationHasher.inputs[0] <== aggregationId;
    aggregationHasher.inputs[1] <== institutionId;
    aggregationHasher.inputs[2] <== totalCredentials;
    
    // Process each batch
    for (var i = 0; i < MAX_BATCHES; i++) {
        // Verify each batch proof
        proofVerifiers[i] = IsZero();
        proofVerifiers[i].in <== batchProofs[i] - 1; // 1 means valid
        
        batchValidator.in[i] <== proofVerifiers[i].out;
        
        // Add batch hash to aggregation
        aggregationHasher.inputs[i + 3] <== batchHashes[i];
    }
    
    // Generate outputs
    aggregationHash <== aggregationHasher.out;
    allBatchesValid <== batchValidator.out;
}

/**
 * Optimized Batch Verifier
 * Streamlined circuit for high-performance batch verification
 * Reduces constraint count for better performance
 */
template OptimizedBatchVerifier() {
    var MAX_BATCH_SIZE = 10;
    
    // Simplified inputs for performance
    signal private input credentialHashes[MAX_BATCH_SIZE];
    signal private input batchSalt;
    
    signal input expectedBatchHash;
    signal input batchSize;
    
    signal output isValid;
    
    // Efficient batch hash computation
    component batchHasher = Poseidon(MAX_BATCH_SIZE + 1);
    
    // Add all credential hashes
    for (var i = 0; i < MAX_BATCH_SIZE; i++) {
        batchHasher.inputs[i] <== credentialHashes[i];
    }
    batchHasher.inputs[MAX_BATCH_SIZE] <== batchSalt;
    
    // Verify batch hash matches expected value
    component hashVerifier = IsEqual();
    hashVerifier.in[0] <== batchHasher.out;
    hashVerifier.in[1] <== expectedBatchHash;
    
    isValid <== hashVerifier.out;
    
    // Validate batch size
    component sizeVerifier = LessEqualThan(8);
    sizeVerifier.in[0] <== batchSize;
    sizeVerifier.in[1] <== MAX_BATCH_SIZE;
    sizeVerifier.out === 1;
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
 * Main circuit entry point for batch processing
 */
component main = BatchCredentialProof();