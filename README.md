# PrivateKreds — code artefact

Smart contracts and Groth16 circuit sources (plus the compiled circuit artefacts and the trusted-setup record) backing the Applied Sciences manuscript *"Privacy-preserving blockchain microcredentials with zero-knowledge selective disclosure: A scalable, GDPR-aligned architecture for higher education"* (applsci-4612892, under revision).

This repository is a scoped release. It contains only the source files that make up the system under study: the Solidity contracts, the Circom circuits, and the auditable key material for the Groth16 verifier. Deployment scripts, backend services, the learner wallet, the issuer and verifier web clients, measurement harnesses, figure-generation scripts, and institutional private keys are intentionally not included. Numerical results reported in the manuscript (on-chain gas, proof-generation and off-chain verification timings, entropy retention) are reproduced from the manuscript's described protocol against the same code.

## Repository layout

| Path | Contents |
|---|---|
| `contracts/` | Solidity sources: `HybridCredentialRegistry.sol` (ERC-1155 dual-mode registry), `ZKVerifier.sol` (the snarkjs-generated Groth16 verifier, from the 0KIMS snarkjs template, 16,855 bytes), `SelectiveDisclosure.sol`, `ICredentialRegistry.sol`. |
| `circuits/credential_proof.circom`, `circuits/batch_proof.circom`, `circuits/revocation_proof.circom` | Full-system circuit sources that make up the broader PrivateKreds architecture. |
| `circuits/selective_disclosure/` | The circuit the manuscript's Section 5 benchmarks run against: `selective_disclosure.circom` (734 constraints by the manuscript's convention, which adds four `validX === 1` predicate-assertion constraints on top of the 730 base constraints `snarkjs r1cs info` reports), the compiled `selective_disclosure.r1cs` and `.sym`, the `selective_disclosure_js/` wrapper with `selective_disclosure.wasm`, the full Phase-1 Powers-of-Tau chain (`pot11_0000.ptau`, `pot11_0001.ptau`, `pot11_final.ptau`), the Phase-2 chain (`circuit_0000.zkey`, `circuit_final.zkey`), the exported `Verifier.sol` (byte-identical to `contracts/ZKVerifier.sol`), the verification key `vkey.json` (nPublic 26), and `CEREMONY.md` with the exact snarkjs commands used to produce each artefact. |

## What is intentionally excluded

Deployment scripts, administrative role-grant scripts, orchestration manifests, backend services, the frontend Next.js applications, any institutional key material, and the measurement scripts and figure-generation code that produced the manuscript's tables and plots. The code here is for inspection and reuse of the system under study, not a one-click reproducibility harness.

## Prerequisites

For contract compilation and circuit work (not for running measurements, which are not shipped):

- Node.js version 20 or later
- Circom 2.1.9 or later
- snarkjs 0.7.6 or later
- Solidity 0.8.20 (the compiler settings used in the manuscript's measurements were `viaIR` with 1000 optimizer runs)

## Trusted-setup ceremony

The Groth16 Phase-1 input shipped here is a local `pot11` ceremony with two contributions (`pot11_0000.ptau` → `pot11_0001.ptau` → `pot11_final.ptau`), extended through a Phase-2 setup with a single local contribution (`circuit_0000.zkey` → `circuit_final.zkey`). This is a demonstration ceremony and the circuit-specific toxic-waste trust therefore sits with the issuer who generated it. Full command transcripts for each artefact are in `circuits/selective_disclosure/CEREMONY.md`.

A production deployment would substitute a public multi-party Phase-2 ceremony with three or more institutional contributors before mainnet issuance, built on top of a widely used Phase-1 input such as the Hermez `pot14` ceremony. The reported on-chain gas and proof-generation workload depend on the circuit and the verifier bytecode and are therefore invariant under a later multi-party ceremony; only the trust assumption changes.

## Licence

MIT. See `LICENSE`.

## Citation

If you use this code, please cite the manuscript:

```
@article{deenmahomed2026privatekreds,
  title   = {Privacy-preserving blockchain microcredentials with zero-knowledge selective disclosure:
             A scalable, GDPR-aligned architecture for higher education},
  author  = {Deenmahomed, Haïdar A. M. and Sungkur, Roopesh K. and Mungur, Avinash},
  journal = {Applied Sciences},
  year    = {2026},
  note    = {Under review (applsci-4612892)}
}
```

## Contact

Haïdar A. M. Deenmahomed · Faculty of ICT, University of Mauritius · <haidar.deenmahomed@umail.uom.ac.mu> · ORCID 0009-0002-4721-0112.
