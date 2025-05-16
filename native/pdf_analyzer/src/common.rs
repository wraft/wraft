use lopdf::{Object};
use serde::Serialize;

// Define constants for the target colors
pub const TARGET_FILL_COLOR: &str = "RGB(214, 255, 244)";
pub const TARGET_STROKE_COLOR: &str = "RGB(0, 184, 148)";

// Helper function to extract f64 from Object, handling Integer and Real
pub fn object_to_f64(obj: &Object) -> f64 {
    match obj {
        Object::Real(n) => (*n).into(), // Convert f32 to f64
        Object::Integer(n) => *n as f64,
        _ => 0.0, // Default or error case
    }
}

// Simplified GraphicsState
#[derive(Debug, Clone)]
pub struct GraphicsState {
    pub stroke_color: String,
    pub fill_color: String,
    pub line_width: f64,
    pub border_width: f64,
    pub current_x: f64,
    pub current_y: f64,
    pub stroke_color_space: String,
    pub fill_color_space: String,
    pub current_font_name: Option<Vec<u8>>,
}

impl Default for GraphicsState {
    fn default() -> Self {
        GraphicsState {
            stroke_color: "Gray(0)".to_string(),
            fill_color: "Gray(0)".to_string(),
            line_width: 1.0,
            border_width: 1.0,
            current_x: 0.0,
            current_y: 0.0,
            stroke_color_space: "DeviceGray".to_string(),
            fill_color_space: "DeviceGray".to_string(),
            current_font_name: None,
        }
    }
}

// Structs for JSON serialization
#[derive(Serialize, Debug)]
pub struct OperatorCount {
    pub operator: String,
    pub occurrences: usize,
}

#[derive(Serialize, Debug)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

#[derive(Serialize, Debug)]
pub struct CornerCoordinates {
    pub x1: f64,
    pub y1: f64,
    pub x2: f64,
    pub y2: f64,
}

#[derive(Serialize, Debug)]
pub struct Dimensions {
    pub width: f64,
    pub height: f64,
}

#[derive(Serialize, Debug)]
pub struct RectangleData {
    pub operation: usize,
    pub position: Point,
    pub dimensions: Dimensions,
    pub corners: CornerCoordinates,
    pub fill_color: String,
    pub stroke_color: String,
    pub line_width: f64,
    pub border: f64,
    pub font_name: Option<String>,
    pub operation_type: String,
    pub fill_color_operands: Vec<f64>,
    pub page: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fill_color_override: Option<String>,
}

#[derive(Serialize, Debug)]
pub struct SummaryStats {
    pub total_operations: usize,
    pub rectangle_operations: usize,
    pub path_operations: usize,
    pub text_operations: usize,
    pub other_operations: usize,
}

#[derive(Serialize, Debug)]
pub struct PageAnalysisResult {
    #[serde(rename = "PDF Page")]
    pub pdf_page: u32,
    #[serde(rename = "Summary")]
    pub summary: SummaryStats,
    #[serde(rename = "MostCommonOperators")]
    pub most_common_operators: Vec<OperatorCount>,
    #[serde(rename = "Rectangles")]
    pub rectangles: Vec<RectangleData>,
}

#[derive(Serialize, Debug)]
pub struct DocumentAnalysisResult {
    pub total_pages: u32,
    pub total_rectangles: usize,
    pub rectangles: Vec<RectangleData>,
}

// Add this struct for LaTeX engine output
#[derive(Serialize, Debug)]
pub struct LatexRectangle {
    pub page: u32,
    pub x1: f64,
    pub y1: f64,
    pub x2: f64,
    pub y2: f64,
    pub width: f64,
    pub height: f64,
}

// Add this struct for LaTeX engine output
#[allow(dead_code)]
#[derive(Serialize, Debug)]
pub struct LatexOutputData {
    pub timestamp: String,
    pub input_file: String,
    pub rectangles: Vec<LatexRectangle>,
}
