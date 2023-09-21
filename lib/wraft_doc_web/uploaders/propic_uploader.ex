defmodule WraftDocWeb.PropicUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias WraftDoc.Client.Minio

  @versions [:original]
  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  # Validate Filetype
  def validate({file, _}) do
    file_extension =
      file.file_name
      |> Path.extname()
      |> String.downcase()

    Enum.member?(@extension_whitelist, file_extension)
  end

  # Change Filename
  def filename(_version, {_file, user}) do
    "profilepic_#{user.name}"
  end

  # Storage Directory
  def storage_dir(_, {_file, profile}) do
    "uploads/avatars/#{profile.id}"
  end

  # Provide a default URL if there hasn't been a file uploaded
  def default_url(_version, _scope), do: Minio.generate_url("uploads/images/avatar.png")
end
