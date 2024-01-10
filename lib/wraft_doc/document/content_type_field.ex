defmodule WraftDoc.Document.ContentTypeField do
  @moduledoc """
  The ContentType Field schema
  """
  alias __MODULE__
  use WraftDoc.Schema

  @fields [:content_type_id, :field_id]

  schema "content_type_field" do
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:field, WraftDoc.Document.Field)

    timestamps()
  end

  def changeset(%ContentTypeField{} = content_type_field, attrs \\ %{}) do
    content_type_field
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> foreign_key_constraint(:content_type_id, message: "Please enter an existing content type")
    |> foreign_key_constraint(:field_id, message: "Please enter a valid field")
    |> unique_constraint(@fields, name: :field_content_type_unique_index, message: "already exist")
  end
end
