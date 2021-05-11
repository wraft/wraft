defmodule WraftDoc.Document.FieldType do
  @moduledoc """
    The field type model.
  """
  use WraftDoc.Schema

  schema "field_type" do
    field(:name, :string, null: false)
    field(:description, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    has_many(:fields, WraftDoc.Document.ContentTypeField)
    has_many(:organisation_fields, WraftDoc.Document.OrganisationField)
    timestamps()
  end

  def changeset(field_type, attrs \\ %{}) do
    field_type
    |> cast(attrs, [:name, :description])
    |> validate_required([:name, :description])
    |> unique_constraint(:name,
      message: "Field type with the same name exists. Use another name.!",
      name: :field_type_unique_index
    )
  end
end
