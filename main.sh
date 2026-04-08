#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOK_DIR="${ROOT_DIR}/rust-book"
PUBLIC_DIR="${ROOT_DIR}/public"
TEMPLATE="${PUBLIC_DIR}/index.template.html"
OUTPUT_INDEX="${PUBLIC_DIR}/index.html"
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
echo "==> Ensuring mdbook-epub is available"
if ! command -v mdbook-epub >/dev/null 2>&1; then
  cargo install mdbook-epub --locked
fi

echo "==> Building rust-book HTML"
(cd "${BOOK_DIR}" && mdbook build)
(cd "${BOOK_DIR}" && mdbook-epub build -o book.epub .)

echo "==> Preparing public site"
rm -rf "${BOOK_OUT}"
mkdir -p "${BOOK_OUT}"
cp -a "${BOOK_DIR}/book/." "${BOOK_OUT}/"
if [ -f "${BOOK_DIR}/book.epub" ]; then
  cp "${BOOK_DIR}/book.epub" "${BOOK_OUT}/book.epub"
fi

if [ ! -f "${TEMPLATE}" ]; then
  echo "Landing page template missing at ${TEMPLATE}" >&2
  exit 1
fi

BOOK_COMMIT=$(git -C "${BOOK_DIR}" rev-parse --short HEAD)
BOOK_DATE=$(git -C "${BOOK_DIR}" show -s --format=%cI HEAD)
perl -pe "s/__COMMIT__/${BOOK_COMMIT}/g; s/__DATE__/${BOOK_DATE}/g" "${TEMPLATE}" > "${OUTPUT_INDEX}"

echo "==> Done"
echo "Open ${OUTPUT_INDEX} to preview the landing page, or ${BOOK_OUT}/index.html for the book."
