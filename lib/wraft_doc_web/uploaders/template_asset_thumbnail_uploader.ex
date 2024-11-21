defmodule WraftDocWeb.TemplateAssetThumbnailUploader do
  @moduledoc """
  This module provides a simple interface for uploading
  preview files to `WraftDoc.TemplateAssets`
  """
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  # Whitelist file extensions:
  @extension_whitelist ~w(.png)

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case Enum.member?(@extension_whitelist, file_extension) do
      true ->
        :ok

      false ->
        {:error, "file type is invalid, currently supporting files is: .png"}
    end
  end

  def filename(_version, {_file, _thumbnail}) do
    "thumbnail"
  end

  def storage_dir(_version, {_file, scope}) do
    case scope.organisation_id do
      nil ->
        scope.zip_file.file_name
        |> Path.rootname()
        |> then(&"public/templates/#{&1}/")

      organisation_id ->
        "organisations/#{organisation_id}/template_assets/#{scope.id}"
    end
  end
end
