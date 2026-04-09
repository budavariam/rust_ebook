use mdbook_preprocessor::{
    book::{Book, BookItem},
    errors::Result,
    Preprocessor, PreprocessorContext,
};
use pulldown_cmark::{CodeBlockKind, Event, Tag};
use pulldown_cmark_to_cmark::cmark;

/// A preprocessor that inserts Ferris crab images above code blocks annotated
/// with `does_not_compile`, `panics`, or `not_desired_behavior`, matching the
/// behaviour of `ferris.js` in the HTML output.
///
/// Only runs for the `epub` renderer; the HTML renderer already handles this
/// via JavaScript.
pub struct TrplFerris;

const FERRIS_TYPES: &[(&str, &str)] = &[
    ("does_not_compile", "This code does not compile!"),
    ("panics", "This code panics!"),
    (
        "not_desired_behavior",
        "This code does not produce the desired behavior.",
    ),
];

impl Preprocessor for TrplFerris {
    fn name(&self) -> &str {
        "trpl-ferris"
    }

    fn run(&self, _ctx: &PreprocessorContext, mut book: Book) -> Result<Book> {
        book.for_each_mut(|item| {
            if let BookItem::Chapter(ref mut chapter) = item {
                chapter.content = rewrite(&chapter.content);
            }
        });
        Ok(book)
    }

    fn supports_renderer(&self, renderer: &str) -> Result<bool> {
        Ok(renderer == "epub")
    }
}

fn ferris_html(ferris_type: &str, title: &str) -> String {
    format!(
        r#"<div class="ferris-container"><img src="img/ferris/{ferris_type}.png" title="{title}" class="ferris ferris-large" /></div>"#
    )
}

fn rewrite(text: &str) -> String {
    let parser = crate::parser(text);
    let mut events: Vec<Event<'_>> = Vec::new();

    for event in parser {
        if let Event::Start(Tag::CodeBlock(CodeBlockKind::Fenced(ref info))) = event {
            let info_str = info.as_ref();
            for (ferris_type, title) in FERRIS_TYPES {
                if info_str.split(',').any(|part| part.trim() == *ferris_type) {
                    events.push(Event::SoftBreak);
                    events.push(Event::SoftBreak);
                    events.push(Event::Html(ferris_html(ferris_type, title).into()));
                    events.push(Event::SoftBreak);
                    events.push(Event::SoftBreak);
                    break;
                }
            }
        }
        events.push(event);
    }

    let mut buf = String::new();
    cmark(events.into_iter(), &mut buf).unwrap();
    buf
}
