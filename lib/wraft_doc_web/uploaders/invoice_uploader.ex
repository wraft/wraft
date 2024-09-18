defmodule WraftDocWeb.InvoiceUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  # Whitelist file extensions:
  def validate({file, _}) do
    Enum.member?(~w(.pdf), Path.extname(file.file_name))
  end

  def filename(_version, {file, _invoice}) do
    file.file_name
    |> Path.rootname()
    |> String.replace(~r/\s+/, "-")
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "organisations/#{scope.organisation_id}/invoice/#{scope.id}"
  end
end
