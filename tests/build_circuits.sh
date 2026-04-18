#!/usr/bin/env bash
set -euo pipefail

NOIR_VERSION="1.0.0-beta.9"
BB_VERSION="v0.87.0"

export PATH="$HOME/.nargo/bin:$HOME/.bb/bin:$PATH"

install_nargo() {
  if ! command -v nargo >/dev/null 2>&1; then
    echo "• installing nargo $NOIR_VERSION"
    curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | \
      NOIR_VERSION="$NOIR_VERSION" bash
    export PATH="$HOME/.nargo/bin:$PATH"
    [ -n "${GITHUB_PATH:-}" ] && echo "$HOME/.nargo/bin" >> "$GITHUB_PATH"

    noirup -v "$NOIR_VERSION"
  fi
}

install_bb() {
  if command -v bb >/dev/null 2>&1; then return; fi

  echo "• installing bb $BB_VERSION"
  mkdir -p "$HOME/.bb/bin"

  uname_s=$(uname -s | tr '[:upper:]' '[:lower:]')
  uname_m=$(uname -m)
  case "${uname_s}_${uname_m}" in
    linux_x86_64)  file="barretenberg-amd64-linux.tar.gz" ;;
    darwin_arm64)  file="barretenberg-arm64-darwin.tar.gz" ;;
    darwin_x86_64) file="barretenberg-amd64-darwin.tar.gz" ;;
    *)             echo "unsupported platform"; exit 1 ;;
  esac

  url="https://github.com/AztecProtocol/aztec-packages/releases/download/${BB_VERSION}/${file}"
  curl -L "$url" -o /tmp/bb.tar.gz
  tar -xzf /tmp/bb.tar.gz -C "$HOME/.bb/bin"
  chmod +x "$HOME/.bb/bin/bb"
  export PATH="$HOME/.bb/bin:$PATH"
  [ -n "${GITHUB_PATH:-}" ] && echo "$HOME/.bb/bin" >> "$GITHUB_PATH"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

install_nargo
install_bb

build_circuit() {
  local dir="$1"
  
  # Extract name from Nargo.toml
  local name=$(grep -E '^name\s*=\s*"' "$dir/Nargo.toml" | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')
  if [[ -z "$name" ]]; then
    name=$(basename "$dir")
    if [[ "$name" == "circuit" ]]; then
      name=$(basename $(dirname "$dir"))
    fi
  fi

  echo "► building $name in $dir"
  pushd "$dir" >/dev/null

  [ -f Prover.toml ] || nargo check --overwrite
  nargo execute

  # Ensure target exists
  mkdir -p target

  local json="target/${name}.json"
  # If the json doesn't exist with the project name, try the directory name or look for any json in target
  if [[ ! -f "$json" ]]; then
    json=$(ls target/*.json | head -n 1)
  fi

  local gz="target/${name}.gz"
  if [[ ! -f "$gz" ]]; then
    gz=$(ls target/*.gz | head -n 1)
  fi

  bb prove -b "$json" -w "$gz" -o target \
    --scheme ultra_honk --oracle_hash keccak --output_format bytes_and_fields

  bb write_vk -b "$json" -o target \
    --scheme ultra_honk --oracle_hash keccak --output_format bytes_and_fields

  if [[ -d target/vk && -f target/vk/vk ]]; then
    mv target/vk/vk target/vk.tmp
    rmdir target/vk
    mv target/vk.tmp target/vk
  fi

  popd >/dev/null
}

# Build circuits in tests/
for dir in tests/* ; do
  [ -d "$dir" ] || continue
  [ -f "$dir/Nargo.toml" ] || continue
  build_circuit "$dir"
done

# Build circuits in contracts/
for dir in contracts/*/circuit ; do
  [ -d "$dir" ] || continue
  [ -f "$dir/Nargo.toml" ] || continue
  build_circuit "$dir"
done

# Build circuits in packages/
for dir in packages/*/circuits/* ; do
  [ -d "$dir" ] || continue
  [ -f "$dir/Nargo.toml" ] || continue
  build_circuit "$dir"
done
