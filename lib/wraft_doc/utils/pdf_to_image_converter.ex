defmodule WraftDoc.Utils.PdfToImageConverter do
  @moduledoc """
  Module that converts PDF to other formats.
  """
  def convert_pdf_to_image(pdf_path) do
    output_path = Path.rootname(pdf_path) <> ".png"

    pdf_path
    |> Mogrify.open()
    |> Mogrify.custom("density", "300")
    |> Mogrify.format("png")
    |> Mogrify.quality("100")
    |> Mogrify.save(path: output_path)

    output_path
  end

  # TODO Add pdf to svg converter
end
