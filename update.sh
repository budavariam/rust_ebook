#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Updating rust-book submodule (tracking origin/main)"
git submodule update --remote --init --recursive

echo "==> Rebuilding site"
"${ROOT_DIR}/main.sh"

echo "Done. Public artifacts refreshed in ${ROOT_DIR}/public/"
