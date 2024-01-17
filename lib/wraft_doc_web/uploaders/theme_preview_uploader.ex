defmodule WraftDocWeb.ThemePreviewUploader do
  @moduledoc """
  This module provides a simple interface for uploading
  preview files to `WraftDoc.Document.Theme`
  """
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  # Whitelist file extensions:
  @extension_whitelist ~w(.pdf .jpg .jpeg .gif .png)

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case Enum.member?(@extension_whitelist, file_extension) do
      true ->
        :ok

      false ->
        {:error,
         "file type is invalid, currently supporting files are: [.pdf .jpg .jpeg .gif .png]"}
    end
  end

  # Define a thumbnail transformation:
  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 250x250^ -gravity center -extent 250x250 -format png", :png}
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "uploads/theme/theme_preview/#{scope.id}"
  end
end
