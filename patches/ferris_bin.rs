use std::io;

use clap::{self, Parser, Subcommand};
use mdbook_preprocessor::Preprocessor;

use mdbook_trpl::Ferris;

fn main() -> Result<(), String> {
    let cli = Cli::parse();
    let ferris = Ferris;
    if let Some(Command::Supports { renderer }) = cli.command {
        return if ferris.supports_renderer(&renderer).unwrap() {
            Ok(())
        } else {
            Err(format!("Renderer '{renderer}' is unsupported"))
        };
    }

    let (ctx, book) = mdbook_preprocessor::parse_input(io::stdin())
        .map_err(|e| format!("{e}"))?;
    let processed = ferris.run(&ctx, book).map_err(|e| format!("{e}"))?;
    serde_json::to_writer(io::stdout(), &processed).map_err(|e| format!("{e}"))
}

#[derive(Parser, Debug)]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Subcommand, Debug)]
enum Command {
    /// Is the renderer supported?
    Supports { renderer: String },
}
