defmodule WraftDocWeb.InvoiceUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  # Whitelist file extensions:
  def validate({file, _}) do
    Enum.member?(~w(.pdf), Path.extname(file.file_name))
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "uploads/invoice/#{scope.id}"
  end
end
