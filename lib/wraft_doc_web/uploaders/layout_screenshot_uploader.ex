defmodule WraftDocWeb.LayoutScreenShotUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

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
  def filename(_version, {_file, layout}) do
    "screenshot_#{layout.name}"
  end

  # Storage Directory
  def storage_dir(_, {_file, layout}) do
    "uploads/layout-screenshots/#{layout.id}"
  end

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)
end
