defmodule WraftDoc.Documents.CollectionFormField do
  @moduledoc """
  Generic collection form
  Example :-  Google form
  """
  alias WraftDoc.Documents.CollectionForm

  use WraftDoc.Schema

  schema "collection_form_field" do
    field(:name, :string)
    field(:description, :string)
    field(:meta, :map)
    field(:field_type, WraftDoc.Fields.FieldTypeEnum)
    belongs_to(:collection_form, CollectionForm)

    timestamps()
  end

  def changeset(collection_form_field, attrs \\ %{}) do
    collection_form_field
    |> cast(attrs, [:name, :description, :meta, :field_type, :collection_form_id])
    |> validate_required([:name, :field_type])
    |> foreign_key_constraint(:collection_form_id)
  end

  def update_changeset(collection_form_field, attrs \\ %{}) do
    collection_form_field
    |> cast(attrs, [:name, :description, :meta, :field_type, :collection_form_id])
    |> validate_required([:name, :field_type])
  end
end
