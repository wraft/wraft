defmodule WraftDocWeb.TemplateAssetUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

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

    case extension_allowed do
      true -> :ok
      false -> {:error, "Invalid zip file size."}
    end
  end

  def filename(_version, {file, _template}) do
    String.replace("template_" <> Path.rootname(file.file_name, ".zip"), ~r/\s+/, "-")
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

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)
end
