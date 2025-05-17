use rustler::{Encoder, Env, NifResult, Term};

// Define modules
mod common;
mod typst;
mod latex;

// Import from modules
use common::{TARGET_FILL_COLOR, TARGET_STROKE_COLOR, DocumentAnalysisResult};

pub fn analyze_pdf(path: &str, engine: Option<&str>) -> Result<DocumentAnalysisResult, String> {
    let engine_type = engine.unwrap_or("typst");

    match engine_type {
        "latex" => latex::analyze_pdf_latex(path, Some(TARGET_FILL_COLOR), Some(TARGET_STROKE_COLOR)),
        _ => typst::analyze_pdf_typst(path, Some(TARGET_FILL_COLOR), Some(TARGET_STROKE_COLOR)),
    }
}

#[rustler::nif(name = "analyze_pdf_nif")]
fn analyze_pdf_nif<'a>(env: Env<'a>, path: &str, _target_fill_color: Option<&str>, _target_stroke_color: Option<&str>, engine: Option<&str>) -> NifResult<Term<'a>> {
    // Ignore the color parameters and use the constants defined at the top of the file
    match analyze_pdf(path, engine) {
        Ok(result) => {
            // Serialize the result to JSON
            let json = serde_json::to_string(&result).map_err(|e| {
                rustler::Error::Term(Box::new(format!("JSON serialization error: {}", e)))
            })?;

            // Create a tuple manually
            let ok_atom = atoms::ok().encode(env);
            let json_string = json.encode(env);

            Ok((ok_atom, json_string).encode(env))
        },
        Err(e) => {
            let error_atom = atoms::error().encode(env);
            let error_string = e.encode(env);
            Ok((error_atom, error_string).encode(env))
        },
    }
}

mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}

rustler::init!("Elixir.WraftDoc.PdfAnalyzer", [analyze_pdf_nif]);
