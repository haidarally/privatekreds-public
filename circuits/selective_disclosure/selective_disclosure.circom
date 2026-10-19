pragma circom 2.1.9;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";

// Selective disclosure circuit matching the paper's deployment:
// 10 credential attributes + salt, Poseidon commitment, threshold + range + set-membership predicates.
//
// Inputs:
//   Private: a[10] (attributes), s (salt)
//   Public:  c (commitment), thresholdGrade, ageMin, ageMax, instSetHash, disclosed[10]
// Constraints enforced:
//   1. Poseidon(a, s) = c
//   2. a[1] (grade) >= thresholdGrade
//   3. ageMin <= a[0] (age) <= ageMax
//   4. a[2] (institutionId) hash matches the accredited set hash
//   5. For each i with mask bit, disclosed[i] = a[i]

template ThresholdCheck(nBits) {
    signal input x;
    signal input threshold;
    signal output isValid;

    component ge = GreaterEqThan(nBits);
    ge.in[0] <== x;
    ge.in[1] <== threshold;
    isValid <== ge.out;
}

template RangeCheck(nBits) {
    signal input x;
    signal input lo;
    signal input hi;
    signal output isValid;

    component geLo = GreaterEqThan(nBits);
    geLo.in[0] <== x;
    geLo.in[1] <== lo;

    component leHi = LessEqThan(nBits);
    leHi.in[0] <== x;
    leHi.in[1] <== hi;

    isValid <== geLo.out * leHi.out;
}

template SelectiveDisclosure() {
    // Private inputs
    signal input a[10];        // attribute vector
    signal input s;            // salt

    // Public inputs
    signal input c;             // commitment hash (Poseidon(a, s))
    signal input thresholdGrade;
    signal input ageMin;
    signal input ageMax;
    signal input instHash;     // Poseidon hash of accredited institution set
    signal input mask[10];     // disclosure mask (0/1)

    // Public outputs
    signal output disclosed[10];
    signal output predicateOk;

    // 1) Commitment check: Poseidon(a, s) == c
    component commit = Poseidon(11);
    for (var i = 0; i < 10; i++) {
        commit.inputs[i] <== a[i];
    }
    commit.inputs[10] <== s;
    c === commit.out;

    // 2) Grade threshold: a[1] >= thresholdGrade (8-bit comparison)
    component gradeCheck = ThresholdCheck(8);
    gradeCheck.x <== a[1];
    gradeCheck.threshold <== thresholdGrade;

    // 3) Age range: ageMin <= a[0] <= ageMax (8-bit)
    component ageCheck = RangeCheck(8);
    ageCheck.x <== a[0];
    ageCheck.lo <== ageMin;
    ageCheck.hi <== ageMax;

    // 4) Institution: Poseidon(a[2]) compared against instHash (placeholder
    //    for a more elaborate set-membership proof; for benchmarking the
    //    constraint cost we use a Poseidon hash equality)
    component instCommit = Poseidon(1);
    instCommit.inputs[0] <== a[2];
    component instEq = IsEqual();
    instEq.in[0] <== instCommit.out;
    instEq.in[1] <== instHash;

    // Combine: predicateOk = gradeOk AND ageOk AND instOk
    signal gradeAndAge;
    gradeAndAge <== gradeCheck.isValid * ageCheck.isValid;
    predicateOk <== gradeAndAge * instEq.out;

    // 5) Selective disclosure: disclosed[i] = mask[i] * a[i]
    //    mask[i] must be 0 or 1 (enforced by constraint mask[i]*(mask[i]-1) == 0)
    for (var i = 0; i < 10; i++) {
        mask[i] * (mask[i] - 1) === 0;
        disclosed[i] <== mask[i] * a[i];
    }
}

component main {public [c, thresholdGrade, ageMin, ageMax, instHash, mask]} = SelectiveDisclosure();
