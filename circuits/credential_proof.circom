pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/mux1.circom";
include "../node_modules/circomlib/circuits/bitify.circom";

/**
 * Credential Proof Circuit
 * Implements zero-knowledge proofs for selective disclosure of credential attributes
 * Addresses RQ1: Privacy and Compliance Integration
 */

template CredentialProof() {
    // Number of attributes that can be selectively disclosed
    var MAX_ATTRIBUTES = 10;
    
    // Private inputs (known only to the prover)
    signal private input credentialData[MAX_ATTRIBUTES];
    signal private input salt;
    signal private input nullifier;
    
    // Public inputs (known to both prover and verifier)
    signal input commitment;
    signal input nullifierHash;
    signal input disclosureMask[MAX_ATTRIBUTES];
    signal input minAge;
    signal input maxAge;
    signal input requiredGrade;
    signal input institutionId;
    signal input credentialType;
    
    // Outputs
    signal output disclosedData[MAX_ATTRIBUTES];
    signal output validAge;
    signal output validGrade;
    signal output validInstitution;
    signal output validType;
    
    // Components
    component hasher = Poseidon(MAX_ATTRIBUTES + 1);
    component nullifierHasher = Poseidon(2);
    component ageChecker = RangeCheck(16); // 16-bit age values
    component gradeChecker = GreaterEqualThan(8); // 8-bit grade values
    component institutionChecker = IsEqual();
    component typeChecker = IsEqual();
    component disclosure[MAX_ATTRIBUTES];
    
    // 1. Verify credential commitment
    // Hash all credential data with salt to create commitment
    for (var i = 0; i < MAX_ATTRIBUTES; i++) {
        hasher.inputs[i] <== credentialData[i];
    }
    hasher.inputs[MAX_ATTRIBUTES] <== salt;
    
    // Commitment verification
    commitment === hasher.out;
    
    // 2. Verify nullifier to prevent double-spending
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHasher.inputs[1] <== salt;
    nullifierHash === nullifierHasher.out;
    
    // 3. Selective disclosure
    // Only reveal attributes where disclosure mask is 1
    for (var i = 0; i < MAX_ATTRIBUTES; i++) {
        disclosure[i] = Mux1();
        disclosure[i].c[0] <== 0; // Hidden value
        disclosure[i].c[1] <== credentialData[i]; // Actual value
        disclosure[i].s <== disclosureMask[i];
        disclosedData[i] <== disclosure[i].out;
    }
    
    // 4. Age range proof (assuming age is at index 0)
    // Prove that minAge <= age <= maxAge without revealing exact age
    ageChecker.in <== credentialData[0];
    ageChecker.min <== minAge;
    ageChecker.max <== maxAge;
    validAge <== ageChecker.out;
    validAge === 1;  // Enforce: age is in [minAge, maxAge]

    // 5. Grade threshold proof (assuming grade is at index 1)
    // Prove that grade >= requiredGrade without revealing exact grade
    gradeChecker.in[0] <== credentialData[1];
    gradeChecker.in[1] <== requiredGrade;
    validGrade <== gradeChecker.out;
    validGrade === 1;  // Enforce: grade >= requiredGrade

    // 6. Institution verification (assuming institution ID is at index 2)
    institutionChecker.in[0] <== credentialData[2];
    institutionChecker.in[1] <== institutionId;
    validInstitution <== institutionChecker.out;
    validInstitution === 1;  // Enforce: credential institution matches

    // 7. Credential type verification (assuming type is at index 3)
    typeChecker.in[0] <== credentialData[3];
    typeChecker.in[1] <== credentialType;
    validType <== typeChecker.out;
    validType === 1;  // Enforce: credential type matches
}

/**
 * Range Check Template
 * Verifies that a value is within a specified range
 */
template RangeCheck(n) {
    signal input in;
    signal input min;
    signal input max;
    signal output out;
    
    component geq = GreaterEqualThan(n);
    component leq = LessEqualThan(n);
    
    geq.in[0] <== in;
    geq.in[1] <== min;
    
    leq.in[0] <== in;
    leq.in[1] <== max;
    
    out <== geq.out * leq.out;
}

/**
 * Batch Credential Proof
 * Proves ownership of multiple credentials simultaneously
 */
template BatchCredentialProof(numCredentials) {
    signal private input credentials[numCredentials][10]; // 10 attributes per credential
    signal private input salts[numCredentials];
    signal private input nullifiers[numCredentials];
    
    signal input commitments[numCredentials];
    signal input nullifierHashes[numCredentials];
    signal input disclosureMasks[numCredentials][10];
    
    signal output batchValid;
    signal output disclosedBatch[numCredentials][10];
    
    component proofs[numCredentials];
    component andGate = MultiAND(numCredentials);
    
    for (var i = 0; i < numCredentials; i++) {
        proofs[i] = CredentialProof();
        
        // Connect inputs
        for (var j = 0; j < 10; j++) {
            proofs[i].credentialData[j] <== credentials[i][j];
            proofs[i].disclosureMask[j] <== disclosureMasks[i][j];
        }
        proofs[i].salt <== salts[i];
        proofs[i].nullifier <== nullifiers[i];
        proofs[i].commitment <== commitments[i];
        proofs[i].nullifierHash <== nullifierHashes[i];
        
        // Default public inputs for batch processing
        proofs[i].minAge <== 0;
        proofs[i].maxAge <== 100;
        proofs[i].requiredGrade <== 0;
        proofs[i].institutionId <== 0;
        proofs[i].credentialType <== 0;
        
        // Collect disclosed data
        for (var j = 0; j < 10; j++) {
            disclosedBatch[i][j] <== proofs[i].disclosedData[j];
        }
        
        // Verify each credential commitment
        andGate.in[i] <== (proofs[i].commitment === commitments[i]) ? 1 : 0;
    }
    
    batchValid <== andGate.out;
}

/**
 * Multi-AND Gate
 * Returns 1 if all inputs are 1, otherwise 0
 */
template MultiAND(n) {
    signal input in[n];
    signal output out;
    
    if (n == 1) {
        out <== in[0];
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
 * Credential Revocation Proof
 * Proves a credential has not been revoked without revealing the credential
 */
template RevocationProof() {
    signal private input credentialId;
    signal private input revocationSecret;
    
    signal input revocationRoot; // Merkle root of revocation list
    signal input revocationProof[10]; // Merkle proof path
    signal input revocationIndices[10]; // Path indices
    
    signal output notRevoked;
    
    component merkleProof = MerkleProof(10);
    component revocationCheck = IsZero();
    
    // Hash credential ID with secret to create revocation leaf
    component leafHasher = Poseidon(2);
    leafHasher.inputs[0] <== credentialId;
    leafHasher.inputs[1] <== revocationSecret;
    
    // Verify merkle proof
    merkleProof.leaf <== leafHasher.out;
    merkleProof.root <== revocationRoot;
    for (var i = 0; i < 10; i++) {
        merkleProof.pathElements[i] <== revocationProof[i];
        merkleProof.pathIndices[i] <== revocationIndices[i];
    }
    
    // If proof is valid, credential is in revocation list (revoked)
    // So we want the opposite: not revoked
    revocationCheck.in <== merkleProof.out;
    notRevoked <== revocationCheck.out;
}

/**
 * Merkle Proof Template
 * Verifies membership in a Merkle tree
 */
template MerkleProof(levels) {
    signal input leaf;
    signal input root;
    signal input pathElements[levels];
    signal input pathIndices[levels];
    
    signal output out;
    
    component hashers[levels];
    component mux[levels];
    
    signal levelHashes[levels + 1];
    levelHashes[0] <== leaf;
    
    for (var i = 0; i < levels; i++) {
        hashers[i] = Poseidon(2);
        mux[i] = MultiMux1(2);
        
        mux[i].c[0] <== levelHashes[i];
        mux[i].c[1] <== pathElements[i];
        mux[i].s <== pathIndices[i];
        
        hashers[i].inputs[0] <== mux[i].out[0];
        hashers[i].inputs[1] <== mux[i].out[1];
        
        levelHashes[i + 1] <== hashers[i].out;
    }
    
    out <== (levelHashes[levels] === root) ? 1 : 0;
}

/**
 * Main circuit entry point
 */
component main = CredentialProof();