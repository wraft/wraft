defmodule WraftDocWeb.TemplateAssetUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias WraftDoc.Client.Minio
  alias WraftDoc.TemplateAssets

  # TODO need to limit zip size
  @max_file_size 1 * 1024 * 1024
  @versions [:original]
  @extension_whitelist ~w(.zip)
  # @required_files ['wraft.json', 'page.md']

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
    ("template_" <> file.file_name)
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/\.zip$/, "")
  end

  def storage_dir(_version, {_file, scope}) do
    "organisations/#{scope.organisation_id}/template_assets/#{scope.id}"
  end

  # TODO - implement default_url if needed
  def default_url(_version, scope),
    do: Minio.generate_url("organisations/#{scope.organisation_id}/template_assets/#{scope.id}")

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)
end
