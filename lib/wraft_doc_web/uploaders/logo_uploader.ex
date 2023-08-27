defmodule WraftDocWeb.LogoUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  # Include ecto support (requires package waffle_ecto installed):
  # use Waffle.Ecto.Definition

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

  def default_url(_version, _scope) do
    WraftDocWeb.Endpoint.url() <> "/priv/static/images/logo.png"
  end
end
