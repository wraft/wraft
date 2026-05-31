defmodule WraftDocWeb.LogoUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias WraftDoc.Client.Minio

  # Limit upload size to 1MB
  @max_file_size 1 * 1024 * 1024

  @versions [:original, :thumb]
  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  def transform(:thumb, _),
    do: {:convert, WraftDocWeb.Uploaders.Thumbnail.convert_string()}

  # Validate File type and size
  def validate({file, _}) do
    file_extension =
      file.file_name
      |> Path.extname()
      |> String.downcase()

    Enum.member?(@extension_whitelist, file_extension) && file_size(file) <= @max_file_size
  end

  # Change Filename
  # Keep :original at the legacy path so existing uploads remain reachable.
  def filename(:original, {_file, organisation}), do: "logo_#{organisation.id}"
  def filename(version, {_file, organisation}), do: "logo_#{version}_#{organisation.id}"

  # Storage Directory
  def storage_dir(_, {_file, organisation}) do
    "organisations/#{organisation.id}/logo"
  end

  def default_url(_version, _scope), do: Minio.generate_url("public/images/logo.png")

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)
end
