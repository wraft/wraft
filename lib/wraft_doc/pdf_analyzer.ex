defmodule WraftDoc.PdfAnalyzer do
  @moduledoc """
  NIF module for analyzing PDF documents.

  This module provides functionality to analyze PDF documents and extract
  information about rectangles and other shapes within the document.
  """

  use Rustler,
    otp_app: :wraft_doc,
    crate: "pdf_analyzer",
    mode: :release

  @doc """
  Analyzes a PDF file and returns information about rectangles in the document.

  For Typst engine, it automatically filters for rectangles with these specific colors:
  - Fill color: RGB(214, 255, 244)
  - Stroke color: RGB(0, 184, 148)

  ## Parameters

  - `path`: Path to the PDF file
  - `engine`: Engine type ("latex" or "typst")

  ## Returns

  - `{:ok, json_string}` - JSON string containing analysis results
  - `{:error, reason}` - Error message if analysis fails
  """
  @spec analyze_pdf(String.t(), String.t() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def analyze_pdf(path, engine) do
    analyze_pdf_nif(path, nil, nil, engine)
  end

  @doc false
  @spec analyze_pdf_nif(String.t(), String.t() | nil, String.t() | nil, String.t() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def analyze_pdf_nif(_path, _target_fill_color, _target_stroke_color, _engine) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Parses the JSON result from analyze_pdf into a map.

  ## Parameters

  - `json_string`: JSON string from analyze_pdf

  ## Returns

  - Map containing the parsed JSON data
  """
  @spec parse_result(String.t()) :: map()
  def parse_result(json_string) do
    Jason.decode!(json_string)
  end
end
