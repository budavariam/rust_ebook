# Rust Book Mirror to GitHub Pages

Simple setup to publish the latest `rust-lang/book` (The Rust Programming Language) to GitHub Pages with a clean landing page.

## Getting started (local)

1. Clone this repo.
2. Run `./init.sh`  
   - fetches the submodule  
   - ensures `mdbook` and `mdbook-epub` are installed  
   - builds the site into `public/` with HTML and EPUB
3. Open `public/index.html` in a browser. The book lives at `public/book/index.html`; EPUB at `public/book/book.epub`.

## Updating to latest upstream

Run:
```bash
./update.sh
```
This pulls the newest `main` of the submodule and rebuilds the site.

## Deploying to GitHub Pages

- Push to `main`. The included workflow builds the book, stages `public/`, and deploys via `actions/deploy-pages`.
- In your GitHub repo settings, set Pages source to "GitHub Actions".
- After first deploy, the live site will be at the Pages URL shown in Settings (e.g., `https://<user>.github.io/<repo>/`). Add that link here once known.

## Layout

- `rust-book/` — submodule tracking `https://github.com/rust-lang/book.git` (branch `main`).
- `public/book/` — generated HTML from mdBook.
- `public/index.html` — custom landing page with a link into the book.
- Scripts: `init.sh` (first-time setup + build), `update.sh` (pull latest + rebuild), `main.sh` (build + render landing page from `public/index.template.html` into `public/index.html`).
- Assets built: `public/book/index.html` (HTML) and `public/book/book.epub` (EPUB download).

No external CSS/JS dependencies are used; everything is bundled as static HTML.
