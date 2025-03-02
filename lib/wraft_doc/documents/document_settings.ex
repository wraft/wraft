defmodule WraftDoc.Documents.DocumentSettings do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:table_of_content?, :boolean, default: true)
    field(:table_of_content_depth, :integer, default: 3)
    field(:qr?, :boolean, default: true)
    field(:default_cover?, :boolean, default: true)
  end

  def changeset(document_settings, attrs \\ %{}) do
    cast(document_settings, attrs, [:table_of_content?, :table_of_content_depth, :qr?, :default_cover?])
  end
end
