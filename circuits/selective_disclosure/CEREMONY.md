# Trusted-setup ceremony (local demonstration)

This file documents the exact commands that produced each artefact in this directory, so a reviewer can walk the chain from `pot11_0000.ptau` to `circuit_final.zkey` and verify the shipped verifier against the shipped `.circom` source.

**This is a local, single-party demonstration ceremony.** Circuit-specific toxic-waste trust sits with whoever generated it. A production deployment must substitute a public multi-party Phase-2 ceremony with three or more independent institutional contributors, built on top of a widely used Phase-1 input such as the Hermez `pot14` ceremony (54 contributions).

## Prerequisites

- Circom 2.1.9 or later
- snarkjs 0.7.6 or later
- Node.js version 20 or later

All commands below assume the current directory is this one (`circuits/selective_disclosure/`).

## Phase 1: Powers of Tau (`pot11`, i.e. 2^11 constraints)

```bash
snarkjs powersoftau new bn128 11 pot11_0000.ptau -v
snarkjs powersoftau contribute pot11_0000.ptau pot11_0001.ptau --name="PrivateKreds local Phase-1 contribution" -v -e="<fresh entropy>"
snarkjs powersoftau prepare phase2 pot11_0001.ptau pot11_final.ptau -v
```

## Compile the circuit

```bash
circom selective_disclosure.circom --r1cs --wasm --sym -o .
```

This produces `selective_disclosure.r1cs`, `selective_disclosure.sym`, and the `selective_disclosure_js/` wrapper containing `selective_disclosure.wasm` and `witness_calculator.js`.

The R1CS summary is:

```bash
snarkjs r1cs info selective_disclosure.r1cs
```

reports 730 non-linear constraints (the paper's convention adds the four `validX === 1` predicate-assertion constraints and reports 734).

## Phase 2: circuit-specific setup

```bash
snarkjs groth16 setup selective_disclosure.r1cs pot11_final.ptau circuit_0000.zkey
snarkjs zkey contribute circuit_0000.zkey circuit_final.zkey --name="PrivateKreds local Phase-2 contribution" -v -e="<fresh entropy>"
snarkjs zkey export verificationkey circuit_final.zkey vkey.json
snarkjs zkey export solidityverifier circuit_final.zkey Verifier.sol
```

The verification key records `nPublic: 26` (15 public inputs plus 11 public outputs), matching `uint[26] calldata _pubSignals` in `Verifier.sol`.

The exported `Verifier.sol` here is byte-identical to `contracts/ZKVerifier.sol` at the repository root; the latter is the deployable copy, this one records the exact snarkjs output alongside the key material.

## Sample proof check

A sample input, witness, and proof are not shipped (to keep the repository to code only); a reviewer who wants to generate a sample proof constructs a witness against the circuit's documented input vector and runs `snarkjs groth16 prove` and `snarkjs groth16 verify` with the shipped `circuit_final.zkey` and `vkey.json`.

## Production ceremony substitution

For a production deployment, replace the two phases above with:

1. **Phase 1**: download the public Hermez `pot14` ceremony transcript (54 contributions, `powersOfTau28_hez_final_14.ptau` from the Hermez S3 bucket; its hash should be verified against the Hermez announcement).
2. **Phase 2**: coordinate a multi-party contribution with three or more independent institutional participants, each running `snarkjs zkey contribute` on a public commit of the previous contribution. Publish the full contribution transcript, including the entropy sources used, so an auditor can walk the chain.

The deployed verifier bytecode, the on-chain gas cost, and the proof-generation time are invariant under this substitution; only the trust assumption changes.
