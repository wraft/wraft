defmodule WraftDocWeb.AssetUploader do
  @moduledoc false
  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias WraftDoc.Assets.Asset
  alias WraftDoc.Client.Minio

  @versions [:original]
  @font_style_name ~w(Regular Italic Bold BoldItalic)

  # Limit upload size to 1MB
  @max_file_size 2 * 1024 * 1024

  # Whitelist file extensions:
  def validate({file, %Asset{type: "layout"}}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    if ".pdf" == file_extension && file_size(file) <= @max_file_size,
      do: :ok,
      else: {:error, "invalid file type"}
  end

  def validate({file, %Asset{type: "theme"}}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case Enum.member?(~w(.otf .ttf), file_extension) && check_file_naming(file.file_name) do
      true -> :ok
      false -> {:error, "invalid file type"}
    end
  end

  def filename(_version, {file, _asset}) do
    file.file_name
    |> Path.rootname()
    |> String.replace(~r/\s+/, "-")
  end

  # Based on what is acceptable in latex engine
  defp check_file_naming(filename) do
    filename
    |> Path.rootname()
    |> String.split("-")
    |> case do
      [_font_family, font_style] when font_style in @font_style_name -> true
      _ -> false
    end
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, asset}) do
    "organisations/#{asset.organisation_id}/assets/#{asset.id}"
  end

  # Provide a default URL if there hasn't been a file uploaded
  def default_url(_version, _scope), do: Minio.generate_url("public/images/avatar.png")

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)
end
