# Rust Book Mirror to GitHub Pages

Simple setup to publish the latest `rust-lang/book` (The Rust Programming Language) to GitHub Pages with a clean landing page.

## Getting started (local)

1. Clone this repo.
2. Run `./init.sh`  
   - fetches the submodule  
   - ensures `mdbook` is installed  
   - builds the site into `public/`
3. Open `public/index.html` in a browser. The book lives at `public/book/index.html`.

## Updating to latest upstream

Run:
```bash
./update.sh
```
This pulls the newest `main` of the submodule and rebuilds the site.

## Deploying to GitHub Pages

- Push to `main`. The included workflow builds the book, stages `public/`, and deploys via `actions/deploy-pages`.
- In your GitHub repo settings, set Pages source to "GitHub Actions".

## Layout

- `rust-book/` — submodule tracking `https://github.com/rust-lang/book.git` (branch `main`).
- `public/book/` — generated HTML from mdBook.
- `public/index.html` — custom landing page with a link into the book.
- Scripts: `init.sh` (first-time setup + build), `update.sh` (pull latest + rebuild), `main.sh` (build + prepare `public/` using template at `public/index.html`).

No external CSS/JS dependencies are used; everything is bundled as static HTML.
