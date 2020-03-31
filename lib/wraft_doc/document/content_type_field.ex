defmodule WraftDoc.Document.ContentTypeField do
  @moduledoc """
  The content type field model.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_type_field" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:field_type, WraftDoc.Document.FieldType)
    timestamps()
  end

  def changeset(field_type, attrs \\ %{}) do
    field_type
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
