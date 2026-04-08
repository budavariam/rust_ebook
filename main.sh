#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOK_DIR="${ROOT_DIR}/rust-book"
PUBLIC_DIR="${ROOT_DIR}/public"
TEMPLATE="${PUBLIC_DIR}/index.template.html"
OUTPUT_INDEX="${PUBLIC_DIR}/index.html"
BOOK_OUT="${PUBLIC_DIR}/book"

# Ensure submodule exists (handles both .git dir and .git file formats)
if [ ! -e "${BOOK_DIR}/.git" ]; then
  echo "==> rust-book submodule missing; initializing"
  git submodule update --init --recursive
fi
if ! git -C "${BOOK_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "rust-book submodule is still missing. Run: git submodule update --init --recursive" >&2
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
echo "==> Building rust-book EPUB"
(cd "${ROOT_DIR}" && mdbook-epub -s rust-book)

echo "==> Preparing public site"
rm -rf "${BOOK_OUT}"
mkdir -p "${BOOK_OUT}"
cp -a "${BOOK_DIR}/book/." "${BOOK_OUT}/"
if [ -f "${BOOK_DIR}/book/The Rust Programming Language.epub" ]; then
  cp "${BOOK_DIR}/book/The Rust Programming Language.epub" "${BOOK_OUT}/book.epub"
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
