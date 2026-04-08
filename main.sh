#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOK_DIR="${ROOT_DIR}/rust-book"
PUBLIC_DIR="${ROOT_DIR}/public"
BOOK_OUT="${PUBLIC_DIR}/book"

if [ ! -d "${BOOK_DIR}/.git" ]; then
  cat >&2 <<'EOF'
rust-book submodule is missing. Run:
  git submodule update --init --recursive
EOF
  exit 1
fi

if [ -f "${HOME}/.cargo/env" ]; then
  # shellcheck disable=SC1091
  source "${HOME}/.cargo/env"
fi

echo "==> Ensuring mdBook is available"
if ! command -v mdbook >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck disable=SC1091
  source "${HOME}/.cargo/env"
  rustup default stable
  cargo install mdbook --locked
fi

echo "==> Building rust-book HTML"
(cd "${BOOK_DIR}" && mdbook build)

echo "==> Preparing public site"
rm -rf "${BOOK_OUT}"
mkdir -p "${BOOK_OUT}"
cp -a "${BOOK_DIR}/book/." "${BOOK_OUT}/"

if [ ! -f "${PUBLIC_DIR}/index.html" ]; then
  echo "Landing page template missing at ${PUBLIC_DIR}/index.html" >&2
  exit 1
fi

echo "==> Done"
echo "Open ${PUBLIC_DIR}/index.html to preview the landing page, or ${BOOK_OUT}/index.html for the book."
