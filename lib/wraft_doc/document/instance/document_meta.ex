defmodule WraftDoc.Document.Instance.DocumentMeta do
  @moduledoc """
    The default document metadata
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, Ecto.Enum, values: [:document])
  end

  def changeset(document_meta, attrs \\ %{}) do
    document_meta
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end
end
