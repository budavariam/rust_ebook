#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOK_DIR="${ROOT_DIR}/rust-book"
PATCHES_DIR="${ROOT_DIR}/patches"
PUBLIC_DIR="${ROOT_DIR}/public"
TEMPLATE="${PUBLIC_DIR}/index.template.html"
OUTPUT_INDEX="${PUBLIC_DIR}/index.html"
BOOK_OUT="${PUBLIC_DIR}/book"
REPO_URL="${REPO_URL:-__REPO_URL_PLACEHOLDER__}"

# Ensure submodule exists (handles both .git dir and .git file formats)
if [ ! -e "${BOOK_DIR}/.git" ]; then
  echo "==> rust-book submodule missing; initializing"
  git submodule update --init --recursive
fi
if ! git -C "${BOOK_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "rust-book submodule is still missing. Run: git submodule update --init --recursive" >&2
  exit 1
fi

_clean_submodule() {
  git -C "${BOOK_DIR}" restore -- .
  git -C "${BOOK_DIR}" clean -fd
}

echo "==> Cleaning rust-book repo (restoring any patched files from previous runs)"
_clean_submodule

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

echo "==> Ensuring rsvg-convert is available (for SVG→PNG conversion)"
if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert not found; please install librsvg (e.g., 'brew install librsvg' or 'sudo apt-get install librsvg2-bin')" >&2
  exit 1
fi

echo "==> Applying epub patches to rust-book"

# New files: epub stylesheet and ferris preprocessor source
cp "${PATCHES_DIR}/epub.css" "${BOOK_DIR}/epub.css"
mkdir -p "${BOOK_DIR}/packages/mdbook-trpl/src/ferris"
cp "${PATCHES_DIR}/ferris_bin.rs"    "${BOOK_DIR}/packages/mdbook-trpl/src/bin/ferris.rs"
cp "${PATCHES_DIR}/ferris/mod.rs"    "${BOOK_DIR}/packages/mdbook-trpl/src/ferris/mod.rs"

# book.toml: append ferris preprocessor and epub output sections
cat >> "${BOOK_DIR}/book.toml" << 'EOF'

[preprocessor.trpl-ferris]
command = "cargo run --manifest-path packages/mdbook-trpl/Cargo.toml --bin mdbook-trpl-ferris"
renderers = ["epub"]

[output.epub]
additional-css = ["epub.css"]
EOF

# Cargo.toml: insert ferris [[bin]] entry before [dependencies]
awk '/^\[dependencies\]/{
  print "[[bin]]"
  print "name = \"mdbook-trpl-ferris\""
  print "path = \"src/bin/ferris.rs\""
  print ""
} 1' "${BOOK_DIR}/packages/mdbook-trpl/Cargo.toml" \
  > /tmp/mdbook_Cargo.toml \
  && mv /tmp/mdbook_Cargo.toml "${BOOK_DIR}/packages/mdbook-trpl/Cargo.toml"

# lib.rs: expose the ferris module
python3 - "${BOOK_DIR}/packages/mdbook-trpl/src/lib.rs" << 'PYEOF'
import sys
path = sys.argv[1]
c = open(path).read()
c = c.replace('mod note;\n', 'mod note;\nmod ferris;\n', 1)
c = c.replace('pub use note::TrplNote as Note;\n', 'pub use note::TrplNote as Note;\npub use ferris::TrplFerris as Ferris;\n', 1)
open(path, 'w').write(c)
PYEOF

# listing/mod.rs: add epub renderer support + fix InlineHtml handling
cp "${PATCHES_DIR}/listing_mod.rs" "${BOOK_DIR}/packages/mdbook-trpl/src/listing/mod.rs"

# note/mod.rs: add epub renderer support
sed -i '' 's/renderer == "test")/renderer == "test" || renderer == "epub")/' \
  "${BOOK_DIR}/packages/mdbook-trpl/src/note/mod.rs"

echo "==> Building rust-book (HTML + EPUB)"
# Convert SVGs to PNGs so epub readers display them correctly, patch markdown
# references temporarily, build, then restore originals.
PATCHED_FILES=()
for svg in "${BOOK_DIR}"/src/img/*.svg "${BOOK_DIR}"/src/img/ferris/*.svg; do
  [ -f "$svg" ] || continue
  png="${svg%.svg}.png"
  [ -f "$png" ] && [ "$png" -nt "$svg" ] || rsvg-convert -w 800 "$svg" -o "$png"
done
while IFS= read -r -d '' mdfile; do
  if grep -q '\.svg' "$mdfile"; then
    sed -i.bak 's|src="\([^"]*\)\.svg"|src="\1.png"|g' "$mdfile"
    PATCHED_FILES+=("$mdfile")
  fi
done < <(find "${BOOK_DIR}/src" -name '*.md' -print0)

(cd "${BOOK_DIR}" && mdbook build)

for mdfile in "${PATCHED_FILES[@]+"${PATCHED_FILES[@]}"}"; do
  mv "${mdfile}.bak" "$mdfile"
done

echo "==> Restoring rust-book repo after build"
_clean_submodule

BOOK_EPUB="${BOOK_DIR}/book/epub/The Rust Programming Language.epub"

echo "==> Preparing public site"
rm -rf "${BOOK_OUT}"
mkdir -p "${BOOK_OUT}"
cp -a "${BOOK_DIR}/book/." "${BOOK_OUT}/"
if [ -f "${BOOK_EPUB}" ]; then
  cp "${BOOK_EPUB}" "${PUBLIC_DIR}/rust.epub"
fi

if [ ! -f "${TEMPLATE}" ]; then
  echo "Landing page template missing at ${TEMPLATE}" >&2
  exit 1
fi

BOOK_COMMIT=$(git -C "${BOOK_DIR}" rev-parse HEAD)
BOOK_COMMIT_SHORT=$(git -C "${BOOK_DIR}" rev-parse --short HEAD)
BOOK_DATE=$(git -C "${BOOK_DIR}" show -s --format=%cI HEAD)
perl -pe "s/__COMMIT__/${BOOK_COMMIT}/g; s/__COMMIT_SHORT__/${BOOK_COMMIT_SHORT}/g; s/__DATE__/${BOOK_DATE}/g; s#__REPO_URL__#${REPO_URL}#g" "${TEMPLATE}" > "${OUTPUT_INDEX}"

echo "==> Done"
echo "Landing page: ${OUTPUT_INDEX}"
echo "HTML book:    ${BOOK_OUT}/index.html"
echo "EPUB:         ${PUBLIC_DIR}/rust.epub"
