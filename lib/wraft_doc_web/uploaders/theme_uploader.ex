defmodule WraftDocWeb.ThemeUploader do
  @moduledoc """
  This module provides a simple interface for uploading
  font files to `WraftDoc.Themes.Theme`
  """

  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  # Whitelist file extensions:
  @extension_whitelist ~w(.ttf .otf)

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case Enum.member?(@extension_whitelist, file_extension) do
      true ->
        :ok

      false ->
        {:error, "file type is invalid, currently supporting files are: [.pdf, .ttf, .otf]"}
    end
  end

  # Change Filename
  def filename(_version, {_file, theme}) do
    "font_" <> String.replace(theme.name, ~r/\s+/, "-")
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "organisations/#{scope.organisation_id}/theme/fonts/#{scope.id}"
  end
end
