defmodule WraftDocWeb.TemplateAssetUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias WraftDoc.TemplateAssets

  @max_file_size 5 * 1024 * 1024
  @versions [:original]
  @extension_whitelist ~w(.zip)

  def validate({file, _}) do
    file_extension =
      file.file_name
      |> Path.extname()
      |> String.downcase()

    extension_allowed =
      Enum.member?(@extension_whitelist, file_extension) && file_size(file) <= @max_file_size

    with true <- extension_allowed,
         :ok <- TemplateAssets.template_zip_validator(file) do
      :ok
    else
      false ->
        {:error, "Invalid file extension."}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def filename(_version, {file, _template}) do
    String.replace("template_" <> Path.rootname(file.file_name, ".zip"), ~r/\s+/, "-")
  end

  def storage_dir(_version, {_file, scope}) do
    "organisations/#{scope.organisation_id}/template_assets/#{scope.id}"
  end

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)
end
