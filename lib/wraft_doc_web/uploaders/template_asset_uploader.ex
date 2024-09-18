defmodule WraftDocWeb.TemplateAssetUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  # Limit upload size to 1MB
  @max_file_size 1 * 1024 * 1024

  @versions [:original]
  @extension_whitelist ~w(.zip)

  # Whitelist file extensions:
  def validate({file, _}) do
    file_extension =
      file.file_name
      |> Path.extname()
      |> String.downcase()

    Enum.member?(@extension_whitelist, file_extension) && file_size(file) <= @max_file_size
  end

  # Change Filename
  def filename(_version, {_file, template}) do
    "template_" <> String.replace(template.name, ~r/\s+/, "-")
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "organisations/#{scope.organisation_id}/template_assets/#{scope.id}"
  end

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)
end
