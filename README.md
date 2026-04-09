# Rust Book Mirror to GitHub Pages

Simple setup to publish the latest `rust-lang/book` (The Rust Programming Language) to GitHub Pages with a clean landing page, including an EPUB download.

## Getting started (local)

Prerequisites: [Rust/cargo](https://rustup.rs) and `rsvg-convert` (`brew install librsvg` on macOS, `sudo apt-get install librsvg2-bin` on Linux).

1. Clone this repo with submodules:
   ```bash
   git clone --recurse-submodules <repo-url>
   ```
2. Run `./main.sh` — applies patches, builds HTML + EPUB, and stages `public/`.
3. Open `public/index.html` in a browser. The book is at `public/book/index.html`; EPUB at `public/rust.epub`.

## Updating to latest upstream

```bash
./update.sh
```

Pulls the newest `main` of the submodule and rebuilds the site.

## Deploying to GitHub Pages

- Push to `main`. The included workflow runs `./main.sh` and deploys `public/` via `actions/deploy-pages`.
- In your GitHub repo settings, set Pages source to "GitHub Actions".

## Layout

- `rust-book/` — submodule tracking `https://github.com/rust-lang/book.git` (branch `main`).
- `patches/` — files applied to the submodule before building: epub stylesheet, Ferris preprocessor source, and patched mdbook-trpl modules.
- `public/` — generated site: `book/` (HTML), `rust.epub` (EPUB download), `index.html` (landing page).
- `main.sh` — full build: applies patches, converts SVGs to PNGs, runs `mdbook build` (produces HTML + EPUB), stages `public/`.
- `update.sh` — pulls latest upstream submodule commit and reruns `main.sh`.

No external CSS/JS dependencies; everything is bundled as static HTML.
