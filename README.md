# rs-soroban-ultrahonk

Soroban contract wrapper around the Noir(UltraHonk) verifier. The VK is set at deploy time; proofs are verified with `public_inputs` and `proof`.

## Requirements Installation

Before you begin, ensure you have the following tools installed:

### 1. Rust and WASM target
Install Rust using [rustup](https://rustup.rs/):
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add wasm32v1-none
```

### 2. Stellar CLI
Install the Soroban/Stellar CLI. We recommend using a recent version:
```bash
cargo install --locked stellar-cli@^3.2.0
```

### 3. Noir and Barretenberg
This project uses **Noir `1.0.0-beta.9`** and **Barretenberg `0.87.0`**. Install them using their respective version managers:
```bash
# Install noirup and switch to Noir 1.0.0-beta.9
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
noirup -v 1.0.0-beta.9

# Install bbup and switch to Barretenberg 0.87.0
curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/master/barretenberg/cpp/installation/install | bash
bbup -v 0.87.0
```

### 4. Node.js
For the helper scripts used to invoke verified transactions (`scripts/invoke_ultrahonk`), ensure you have Node.js and npm installed:
- [Install Node.js](https://nodejs.org/)

### 5. Docker
Docker is required to run the local Standalone Network container (`stellar container start`).
- [Install Docker Desktop](https://www.docker.com/products/docker-desktop/) or Docker Engine depending on your system.

## Quickstart (localnet)

Prereqs:
- `stellar` CLI (stellar-cli)
- Rust + `wasm32v1-none` target
- Docker (for localnet)

```bash
# 1) Start localnet
stellar container start -t future --name local --limits unlimited

# 2) Configure network + identity
stellar network add local \
  --rpc-url http://localhost:8000/soroban/rpc \
  --network-passphrase "Standalone Network ; February 2017"
stellar network use local
stellar network health --output json
stellar keys generate --global alice
stellar keys fund alice --network local
stellar keys address alice

# 3) Build + deploy (constructor requires a VK from tests/build_circuits.sh)
rustup target add wasm32v1-none
stellar contract build
stellar contract deploy \
  --wasm target/wasm32v1-none/release/rs_soroban_ultrahonk.wasm \
  --source alice \
  -- \
  --vk_bytes-file-path tests/simple_circuit/target/vk
```

## Invoke verify_proof

### Build ZK artifacts (vk/proof/public_inputs)

From the repo root. You need Noir tooling (`nargo`) and `bb` (barretenberg). Artifacts are generated with `--oracle_hash keccak`.

```bash
tests/build_circuits.sh
```

### Use the helper script

Expects a dataset folder with `public_inputs`, `proof` (the VK is already on-chain from deploy):

```bash
cd scripts/invoke_ultrahonk
npm install
npx ts-node invoke_ultrahonk.ts invoke \
  --dataset ../../tests/simple_circuit/target \
  --contract-id <CONTRACT_ID> \
  --network local \
  --source-account alice \
  --send yes
```

### Direct CLI invoke

```bash
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source alice \
  --network local \
  --send yes \
  --cost \
  -- \
  verify_proof \
  --public_inputs-file-path tests/simple_circuit/target/public_inputs \
  --proof_bytes-file-path tests/simple_circuit/target/proof
```

## VK policy (important)

This contract does not enforce access control:
- `__constructor` stores the VK once at deploy time (immutable after first set).
- `verify_proof` always uses the stored VK set at deploy.

## Tests

```bash
RUST_TEST_THREADS=1 cargo test --test integration_tests -- --nocapture
cargo test --manifest-path tornado_classic/contracts/Cargo.toml --features testutils -- --nocapture
```

## References

- Noir language: https://noir-lang.org/
- Barretenberg (bb): https://github.com/AztecProtocol/aztec-packages
- rs-soroban-ultrahonk: https://github.com/yugocabrio/rs-soroban-ultrahonk
- Soroban documentation: https://developers.stellar.org/docs/build/smart-contracts
- Soroban SDK (Rust): https://github.com/stellar/rs-soroban-sdk

## Audit status

This project has not been audited.

## License

MIT
