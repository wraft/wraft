defmodule WraftDoc.Document.CollectionFormField do
  @moduledoc """
  Generic collection form
  Example :-  Google form
  """
  alias WraftDoc.Document.CollectionForm

  use WraftDoc.Schema

  schema "collection_form_field" do
    field(:name, :string, null: false)
    field(:description, :string)
    belongs_to(:collection_form, CollectionForm)

    timestamps()
  end

  def changeset(collection_form_field, attrs \\ %{}) do
    collection_form_field
    |> cast(attrs, [:name, :description, :collection_form_id])
    |> validate_required([:name, :collection_form_id])
    |> foreign_key_constraint(:collection_form_id)
  end

  def update_changeset(collection_form_field, attrs \\ %{}) do
    collection_form_field
    |> cast(attrs, [:name, :description, :collection_form_id])
    |> validate_required([:name])
  end
end
