defmodule WraftDoc.Document.ContentTypeField do
  @moduledoc """
  The content type field model.
  """
  use WraftDoc.Schema

  schema "content_type_field" do
    field(:name, :string)
    field(:meta, :map)
    field(:description, :string)
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:field_type, WraftDoc.Document.FieldType)
    timestamps()
  end

  def changeset(field_type, attrs \\ %{}) do
    field_type
    |> cast(attrs, [:name, :meta])
    |> validate_required([:name])
    |> unique_constraint(:name,
      message: "Field type already added.!",
      name: :content_type_field_unique_index
    )
  end
end
