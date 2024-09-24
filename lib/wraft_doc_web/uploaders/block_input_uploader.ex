defmodule WraftDocWeb.BlockInputUploader do
  @moduledoc false
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  def filename(_version, {file, _block}) do
    file.file_name
    |> Path.rootname()
    |> String.replace(~r/\s+/, "-")
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "organisations/#{scope.organisation_id}/block_input/#{scope.id}"
  end
end
