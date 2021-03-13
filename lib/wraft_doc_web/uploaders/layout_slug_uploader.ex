defmodule WraftDocWeb.LayoutSlugUploader do
  @moduledoc false
  use Arc.Definition
  use Arc.Ecto.Definition

  @versions [:original]
  # @extension_whitelist ~w(.jpg .jpeg .gif .png)

  # Validate Filetype
  # def validate({file, _}) do
  #   file_extension =
  #     file.file_name
  #     |> Path.extname()
  #     |> String.downcase()

  #   Enum.member?(@extension_whitelist, file_extension)
  # end

  # Change Filename
  def filename(_version, {_file, layout}) do
    "slug_#{layout.name}_#{layout.updated_at}"
  end

  # Storage Directory
  def storage_dir(_, {_file, layout}) do
    "uploads/slug/#{layout.id}"
  end
end
