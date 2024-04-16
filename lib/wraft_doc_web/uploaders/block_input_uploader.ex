defmodule WraftDocWeb.BlockInputUploader do
  @moduledoc false
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "uploads/block_input/#{scope.id}"
  end
end
