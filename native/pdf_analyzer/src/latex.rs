use crate::common::{CornerCoordinates, Dimensions, DocumentAnalysisResult, Point, RectangleData};
use lopdf::{Document, Object};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
struct SignatureField {
    page: u32,
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
    width: f64,
    height: f64,
}

fn detect_signature_fields(pdf_path: &Path) -> Result<Vec<SignatureField>, String> {
    let doc = Document::load(pdf_path).map_err(|e| format!("Failed to load PDF: {}", e))?;
    let mut signature_fields = Vec::new();

    // Process each page
    for (page_idx, page_id) in doc.page_iter().enumerate() {
        if let Ok(Object::Dictionary(page_dict)) = doc.get_object(page_id) {
            if let Ok(annots_obj) = page_dict.get(b"Annots") {
                // Get annotations array
                let annots = if let Object::Array(arr) = annots_obj {
                    arr.clone()
                } else if let Object::Reference(ref_id) = annots_obj {
                    if let Ok(Object::Array(arr)) = doc.get_object(*ref_id) {
                        arr.clone()
                    } else {
                        continue;
                    }
                } else {
                    continue;
                };

                // Process each annotation
                for annot_ref in annots.iter() {
                    if let Ok(annot_id) = annot_ref.as_reference() {
                        if let Ok(Object::Dictionary(annot_dict)) = doc.get_object(annot_id) {
                            // Check if this is a signature field
                            if let Ok(Object::Name(ft)) = annot_dict.get(b"FT") {
                                if ft.as_slice() == b"Sig" {
                                    // This is a signature field, get its rectangle
                                    if let Ok(Object::Array(rect_array)) = annot_dict.get(b"Rect") {
                                        if rect_array.len() == 4 {
                                            let mut coords = Vec::new();
                                            for val in rect_array.iter() {
                                                if let Object::Real(num) = val {
                                                    coords.push(*num as f64);
                                                } else if let Object::Integer(num) = val {
                                                    coords.push(*num as f64);
                                                }
                                            }

                                            if coords.len() == 4 {
                                                signature_fields.push(SignatureField {
                                                    page: page_idx as u32 + 1, // Adjust page number to be 1-based
                                                    x0: coords[0],
                                                    y0: coords[1],
                                                    x1: coords[2],
                                                    y1: coords[3],
                                                    width: coords[2] - coords[0],
                                                    height: coords[3] - coords[1],
                                                });
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Ok(signature_fields)
}

pub fn analyze_pdf_latex(
    path: &str,
    _target_fill_color: Option<&str>,
    _target_stroke_color: Option<&str>,
) -> Result<DocumentAnalysisResult, String> {
    let path_buf = PathBuf::from(path);
    let signature_fields = detect_signature_fields(&path_buf)
        .map_err(|e| format!("Failed to detect signature fields: {}", e))?;

    let mut rectangles = Vec::new();

    for field in signature_fields {
        let rect = RectangleData {
            operation: 0,
            position: Point {
                x: field.x0,
                y: field.y0,
            },
            dimensions: Dimensions {
                width: field.width,
                height: field.height,
            },
            corners: CornerCoordinates {
                x1: field.x0,
                y1: field.y0,
                x2: field.x1,
                y2: field.y1,
            },
            fill_color: "Unknown".to_string(),
            stroke_color: "Unknown".to_string(),
            line_width: 1.0,
            border: 1.0,
            font_name: None,
            operation_type: "SignatureField".to_string(),
            fill_color_operands: vec![],
            page: field.page,
            fill_color_override: None,
        };

        rectangles.push(rect);
    }

    // Get total pages
    let total_pages = match Document::load(&path_buf) {
        Ok(doc) => doc.get_pages().len() as u32,
        Err(_) => 0,
    };

    Ok(DocumentAnalysisResult {
        total_pages,
        total_rectangles: rectangles.len(),
        rectangles,
    })
}
