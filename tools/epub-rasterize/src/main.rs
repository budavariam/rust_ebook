use anyhow::{Context, Result};
use regex::Regex;
use resvg::tiny_skia::Transform;
use std::{
    fs,
    io::{Read, Write},
    path::{Path, PathBuf},
};
use tempfile::TempDir;
use tiny_skia::Pixmap;
use usvg;
use walkdir::WalkDir;
use zip::{write::FileOptions, ZipArchive, ZipWriter};

const FERRIS_SVGS: &[(&str, &str, &str)] = &[
    ("does_not_compile", "img/ferris/does_not_compile.svg", "This code does not compile!"),
    ("panics", "img/ferris/panics.svg", "This code panics!"),
    ("not_desired_behavior", "img/ferris/not_desired_behavior.svg", "This code does not produce the desired behavior."),
];

fn main() -> Result<()> {
    let epub = std::env::args()
        .nth(1)
        .map(PathBuf::from)
        .context("usage: epub-rasterize <path-to-epub>")?;

    process_epub(&epub)?;
    Ok(())
}

fn process_epub(epub_path: &Path) -> Result<()> {
    let tmp = TempDir::new()?;
    let tmp_path = tmp.path();

    // unzip
    {
        let file = fs::File::open(epub_path)?;
        let mut archive = ZipArchive::new(file)?;
        archive.extract(tmp_path)?;
    }

    let oebps = tmp_path.join("OEBPS");
    let img_dir = oebps.join("img");
    let copied = copy_ferris_assets(&img_dir)?;
    println!("Copied ferris assets: {}", copied);

    // inject ferris icons into HTML/XHTML
    let re = Regex::new(r#"<pre><code\s+class="([^"]*)">"#)?;
    let mut injected_blocks = 0usize;
    for entry in WalkDir::new(&oebps).min_depth(1).max_depth(1) {
        let entry = entry?;
        let path = entry.path();
        if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
            if ext == "html" || ext == "xhtml" {
                let mut text = fs::read_to_string(path)?;
                if text.contains("ferris-callout") {
                    continue;
                }
                let (new_text, added) = inject_ferris(&text, &re);
                injected_blocks += added;
                text = new_text;
                text = inject_style(&text);
                fs::write(path, text)?;
            }
        }
    }
    println!("Injected ferris callouts into {} code blocks", injected_blocks);

    // add ferris svgs/pngs to manifest if needed
    let opf = oebps.join("content.opf");
    let mut opf_text = fs::read_to_string(&opf)?;
    for (_, rel, _) in FERRIS_SVGS {
        let fname = Path::new(rel).file_name().unwrap().to_string_lossy();
        if !opf_text.contains(&fname.to_string()) {
            opf_text = opf_text.replace(
                "</manifest>",
                &format!(
                    r#"<item id="{id}" href="{href}" media-type="image/svg+xml"/>
</manifest>"#,
                    id = fname,
                    href = rel
                ),
            );
        }
        let png = fname.replace(".svg", ".png");
        if !opf_text.contains(&png) {
            opf_text = opf_text.replace(
                "</manifest>",
                &format!(
                    r#"<item id="{id}" href="img/ferris/{href}" media-type="image/png"/>
</manifest>"#,
                    id = png,
                    href = png
                ),
            );
        }
    }
    fs::write(&opf, opf_text)?;

    // rasterize all svg -> png and rewrite references
    let (svg_count, png_count) = rasterize_svgs(&oebps)?;
    println!("Rasterized {} SVGs -> {} PNGs", svg_count, png_count);

    // rezip with mimetype first, stored
    rezip(epub_path, tmp_path)?;
    Ok(())
}

fn inject_ferris(text: &str, re: &Regex) -> (String, usize) {
    let mut count = 0usize;
    let out = re.replace_all(text, |caps: &regex::Captures| {
        let classes = &caps[1];
        let mut icon = None;
        for (attr, rel, alt) in FERRIS_SVGS {
            if classes.contains(attr) {
                icon = Some((*rel, *alt));
                break;
            }
        }
        if let Some((rel, alt)) = icon {
            count += 1;
            format!(
                r#"<div class="ferris-callout"><img src="{src}" alt="{alt}"/></div><pre><code class="{cls}">"#,
                src = rel,
                alt = alt,
                cls = classes
            )
        } else {
            caps[0].to_string()
        }
    })
    .to_string();
    (out, count)
}

fn inject_style(text: &str) -> String {
    if text.contains(".ferris-callout") {
        return text.to_string();
    }
    let style = r#"<style>
.ferris-callout { margin: 0 0 8px 0; }
.ferris-callout img { height: 36px; vertical-align: middle; }
</style>
"#;
    text.replacen("</head>", &(style.to_string() + "</head>"), 1)
}

fn rasterize_svgs(oebps: &Path) -> Result<(usize, usize)> {
    // convert svg files under OEBPS/img and OEBPS/img/ferris
    let img_dir = oebps.join("img");
    let mut svg_count = 0usize;
    let mut png_count = 0usize;
    for entry in WalkDir::new(&img_dir).min_depth(1) {
        let entry = entry?;
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) == Some("svg") {
            svg_count += 1;
            let png_path = path.with_extension("png");
            svg_to_png(path, &png_path)?;
            png_count += 1;
        }
    }

    // replace refs in html/xhtml/opf/ncx
    for entry in WalkDir::new(oebps).min_depth(1).max_depth(1) {
        let entry = entry?;
        let path = entry.path();
        if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
            if matches!(ext, "html" | "xhtml" | "opf" | "ncx") {
                let content = fs::read_to_string(path)?;
                let content = content
                    .replace(".svg", ".png")
                    .replace("image/svg+xml", "image/png");
                fs::write(path, content)?;
            }
        }
    }
    Ok((svg_count, png_count))
}

fn copy_ferris_assets(img_dir: &Path) -> Result<usize> {
    let ferris_dest = img_dir.join("ferris");
    fs::create_dir_all(&ferris_dest)?;

    let candidates = [
        Path::new("rust-book/book/html/img/ferris"),
        Path::new("rust-book/src/img/ferris"),
    ];
    let mut copied = 0usize;
    for src in candidates {
        if src.exists() {
            for entry in fs::read_dir(src)? {
                let entry = entry?;
                let path = entry.path();
                if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
                    if ext.eq_ignore_ascii_case("svg") || ext.eq_ignore_ascii_case("png") {
                        let name = path.file_name().unwrap();
                        fs::copy(&path, ferris_dest.join(name))?;
                        copied += 1;
                    }
                }
            }
        }
    }
    Ok(copied)
}

fn svg_to_png(svg_path: &Path, png_path: &Path) -> Result<()> {
    let mut svg_data = Vec::new();
    fs::File::open(svg_path)?.read_to_end(&mut svg_data)?;

    let opt = usvg::Options::default();
    let mut fontdb = usvg::fontdb::Database::new();
    fontdb.load_system_fonts();
    let tree = usvg::Tree::from_data(&svg_data, &opt, &fontdb)?;

    let size = tree.size();
    let mut pixmap =
        Pixmap::new(size.width().round() as u32, size.height().round() as u32).context("pixmap")?;

    let mut pmut = pixmap.as_mut();
    resvg::render(&tree, Transform::identity(), &mut pmut);

    pixmap.save_png(png_path)?;
    Ok(())
}

fn rezip(epub_path: &Path, tmp_path: &Path) -> Result<()> {
    let outfile = fs::File::create(epub_path)?;
    let mut writer = ZipWriter::new(outfile);

    // mimetype first, stored
    let mime_path = tmp_path.join("mimetype");
    if mime_path.exists() {
        let opts = FileOptions::default().compression_method(zip::CompressionMethod::Stored);
        writer.start_file("mimetype", opts)?;
        let data = fs::read(mime_path)?;
        writer.write_all(&data)?;
    }

    let deflate_opts = FileOptions::default().compression_method(zip::CompressionMethod::Deflated);
    for entry in WalkDir::new(tmp_path) {
        let entry = entry?;
        let path = entry.path();
        let rel = path.strip_prefix(tmp_path)?;
        if path.is_dir() || rel == Path::new("mimetype") {
            continue;
        }
        writer.start_file(rel.to_string_lossy(), deflate_opts)?;
        let mut f = fs::File::open(path)?;
        std::io::copy(&mut f, &mut writer)?;
    }
    writer.finish()?;
    Ok(())
}
