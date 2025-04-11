defmodule WraftDocWeb.PropicUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias WraftDoc.Client.Minio

  # Limit upload size to 1MB
  @max_file_size 1 * 1024 * 1024

  @versions [:original]
  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  # Validate File type and size
  def validate({file, _}) do
    file_extension =
      file.file_name
      |> Path.extname()
      |> String.downcase()

    Enum.member?(@extension_whitelist, file_extension) && file_size(file) <= @max_file_size
  end

  # Change Filename
  def filename(_version, {_file, user}) do
    "profilepic_" <> String.replace(user.id, ~r/\s+/, "-")
  end

  # Storage Directory
  def storage_dir(_, {_file, profile}) do
    "users/#{profile.user_id}/profile"
  end

  # Provide a default URL if there hasn't been a file uploaded
  def default_url(_version, _scope), do: Minio.generate_url("public/images/avatar.png")

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)
end
