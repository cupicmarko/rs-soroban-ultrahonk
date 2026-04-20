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

We've provided streamlined scripts to easily start the network, build the ZK artifacts, and execute the verifier on-chain.

### 1. Start the Network
Start a local Stellar network in a Docker container and configure your environment:
```bash
./scripts/start_stellar.sh
```
*(Optional: Pass `--limits unlimited` if you need to override Docker resource limits)*

### 2. Deploy the Contract
This script will automatically fund your `alice` test account, compile the Noir circuits, build the Soroban contract for your local target, and deploy it to the localnet.
```bash
./scripts/deploy.sh
```
*(The generated `CONTRACT_ID` is saved locally to `.contract_id`)*

### 3. Verify a Proof
To simulate the verifier on-chain using the ZK proofs generated in the previous step:
```bash
./scripts/verify.sh
```
*(This automatically reads from `.contract_id` and executes `verify_proof` against your deployed contract)*

### Stop the Network
When you're done, tear down the container:
```bash
./scripts/stop_stellar.sh
```

## Advanced usage

### Use the JS helper script

Expects a dataset folder with `public_inputs`, `proof` (the VK is already on-chain from deploy):

```bash
cd scripts/invoke_ultrahonk
npm install
npx ts-node invoke_ultrahonk.ts invoke \
  --dataset ../../contracts/rs-soroban-ultrahonk/tests/simple_circuit/target \
  --contract-id $(cat ../../.contract_id) \
  --network local \
  --source-account alice \
  --send yes
```

## VK policy (important)

This contract does not enforce access control:
- `__constructor` stores the VK once at deploy time (immutable after first set).
- `verify_proof` always uses the stored VK set at deploy.

## Tests

Run all unit and integration tests across the Cargo workspace (including `rs-soroban-ultrahonk` and `tornado_classic`):

```bash
cargo test --workspace --all-features --release
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
