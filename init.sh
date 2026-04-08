#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Initializing submodules"
git submodule update --init --recursive

echo "==> Installing mdBook (if missing)"
if ! command -v mdbook >/dev/null 2>&1; then
  if ! command -v rustup >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  # shellcheck disable=SC1091
  [ -f "${HOME}/.cargo/env" ] && source "${HOME}/.cargo/env"
  rustup default stable
  cargo install mdbook --locked
fi

echo "==> Building site"
"${ROOT_DIR}/main.sh"

echo "All set. Preview at ${ROOT_DIR}/public/index.html"
