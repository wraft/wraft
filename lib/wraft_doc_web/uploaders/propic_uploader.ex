defmodule WraftDocWeb.PropicUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  # Include ecto support (requires package waffle_ecto installed):
  # use Waffle.Ecto.Definition

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
  def storage_dir(_, {_file, user}) do
    "uploads/avatars/#{user.id}"
  end

  # Provide a default URL if there hasn't been a file uploaded
  def default_url(_version, _scope) do
    WraftDocWeb.Endpoint.url() <> "/test/helper/images.png"
  end
end
