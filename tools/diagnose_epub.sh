#!/usr/bin/env bash
set -euo pipefail

# Diagnostics for EPUB image embedding.
# Default target: ./public/book/book.epub (override with $EPUB_PATH)

EPUB="${EPUB_PATH:-./public/book/book.epub}"

if [ ! -f "${EPUB}" ]; then
  echo "EPUB not found at ${EPUB}" >&2
  exit 1
fi

echo "==> Inspecting manifest media types (content.opf)"
unzip -p "${EPUB}" OEBPS/content.opf | grep -Ei 'item.*(svg|png|jpeg|jpg|gif|webp|image)' || echo "No image entries found"

echo
echo "==> Counting remaining SVG assets (should be 0 after rasterization)"
unzip -l "${EPUB}" | awk '{print $4}' | grep -i '\.svg$' || echo "No SVG files present"

echo
echo "==> Counting raster images"
unzip -l "${EPUB}" | awk '{print $4}' | grep -Ei '\.(png|jpe?g|gif|webp)$' | sed 's#.*/##' | sort | uniq -c | sort -nr | head -20

echo
echo "==> Sampling first 5 HTML/XHTML files for <img> tags"
unzip -l "${EPUB}" | awk '{print $4}' | grep -E '\.(x)?html$' | head -5 | while read -r f; do
  echo "-- ${f} --"
  unzip -p "${EPUB}" "${f}" | grep -iE '<img|src=' || echo "  (no img/src refs)"
done

echo
echo "==> Verifying mimetype placement (should be first, stored)"
zipinfo -1 "${EPUB}" | head -1
zipinfo -v "${EPUB}" | awk '/mimetype/{print}'

unzip -l "./public/book/book.epub" | awk '{print $4}' | grep '\.html$' | while read f; do
  result=$(unzip -p "./public/book/book.epub" "$f" | grep -i 'trpl' 2>/dev/null)
  [ -n "$result" ] && echo "==$f==" && echo "$result"
done

echo
echo "Done."
