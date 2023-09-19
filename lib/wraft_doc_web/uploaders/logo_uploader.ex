defmodule WraftDocWeb.LogoUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias WraftDoc.Client.Minio

  @versions [:original]
  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  def validate({file, _}) do
    file_extension =
      file.file_name
      |> Path.extname()
      |> String.downcase()

    Enum.member?(@extension_whitelist, file_extension)
  end

  # Change Filename
  def filename(_version, {_file, organisation}) do
    "logo_#{organisation.name}"
  end

  # Storage Directory
  def storage_dir(_, {_file, organisation}) do
    "uploads/logos/#{organisation.id}"
  end

  def default_url(_version, _scope), do: Minio.generate_url("uploads/images/logo.png")
end
