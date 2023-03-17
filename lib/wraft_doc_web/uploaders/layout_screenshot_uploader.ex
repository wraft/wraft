defmodule WraftDocWeb.LayoutScreenShotUploader do
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
  def filename(_version, {_file, layout}) do
    "screenshot_#{layout.name}"
  end

  # Storage Directory
  def storage_dir(_, {_file, layout}) do
    "uploads/layout-screenshots/#{layout.id}"
  end
end
