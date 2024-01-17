defmodule WraftDocWeb.AssetUploader do
  @moduledoc false
  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias WraftDoc.Client.Minio
  alias WraftDoc.Document.Asset

  @versions [:original]
  @font_style_name ~w(Regular Italic Bold BoldItalic)

  # Whitelist file extensions:
  def validate({file, %Asset{type: "layout"}}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    if ".pdf" == file_extension, do: :ok, else: {:error, "invalid file type"}
  end

  def validate({file, %Asset{type: "theme"}}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case Enum.member?(~w(.otf .ttf), file_extension) && check_file_naming(file.file_name) do
      true -> :ok
      false -> {:error, "invalid file type"}
    end
  end

  # Based on what is acceptable in latex engine
  def check_file_naming(filename) do
    filename
    |> Path.rootname()
    |> String.split("-")
    |> case do
      [_font_family, font_style] when font_style in @font_style_name -> true
      _ -> false
    end
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "uploads/assets/#{scope.id}"
  end

  # Provide a default URL if there hasn't been a file uploaded
  def default_url(_version, _scope), do: Minio.generate_url("uploads/images/avatar.png")
end
