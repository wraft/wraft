defmodule WraftDocWeb.LogoUploader do
  use Arc.Definition
  use Arc.Ecto.Definition

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
    "logo_#{organisation.name}_#{organisation.updated_at}"
  end

  # Storage Directory
  def storage_dir(_, {_file, organisation}) do
    "uploads/logos/#{organisation.id}"
  end
end
