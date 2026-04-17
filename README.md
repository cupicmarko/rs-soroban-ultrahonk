# rs-soroban-ultrahonk

Soroban contract wrapper around the Noir(UltraHonk) verifier. The VK is set at deploy time; proofs are verified with `public_inputs` and `proof`.

## Requirements

To build and deploy this project, you need the following tools installed:

### 1. Rust and WASM target

Install [Rust](https://www.rust-lang.org/tools/install) via `rustup`:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add wasm32v1-none
```

### 2. Stellar CLI

Install the `stellar` CLI using `cargo`:

```bash
cargo install --locked stellar-cli
```

### 3. Noir and Barretenberg

Install `nargo` (Noir) and `bb` (Barretenberg). The project is optimized for Noir version `1.0.0-beta.9`.

```bash
# Install noirup
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
# Install specific version
noirup -v 1.0.0-beta.9

# Install barretenberg (bb)
# Follow the instructions in tests/build_circuits.sh for manual installation
# or simply run the script to handle it automatically.
```

### 4. Docker

Docker is required to run the Soroban local network.

- **Windows / macOS**: Install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
- **Ubuntu**: 
  ```bash
  sudo apt update && sudo apt install docker.io
  sudo usermod -aG docker $USER # Logout and back in
  ```
- **Fedora / OpenSUSE**: 
  ```bash
  # Fedora
  sudo dnf install moby-engine docker-compose
  # OpenSUSE
  sudo zypper install docker docker-compose
  
  sudo systemctl enable --now docker
  sudo usermod -aG docker $USER
  ```
- **Arch Linux**:
  ```bash
  sudo pacman -S docker
  sudo systemctl enable --now docker
  sudo usermod -aG docker $USER
  ```


---

## Development & Redeployment

If you modify the Noir circuits or the Rust contract, you can rebuild and redeploy everything in one command:

```bash
./scripts/rebuild_and_deploy.sh
```

This script handles:
1. Re-compiling Noir circuits and generating a new Verification Key (VK).
2. Re-building the Soroban Rust contract.
3. Deploying a new contract instance with the updated VK.

---

## Invoke verify_proof

Prereqs:
- See [Requirements](#requirements) above.

```bash
# 1) Start localnet
stellar container start -t future --name local --limits unlimited

# 2) Configure network + identity
stellar network add local \
  --rpc-url http://localhost:8000/soroban/rpc \
  --network-passphrase "Standalone Network ; February 2017"
stellar network use local
stellar network health --output json
stellar keys generate alice
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
