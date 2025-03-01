defmodule WraftDoc.Documents.FieldType do
  @moduledoc """
    The field type schema.
  """
  alias __MODULE__
  use WraftDoc.Schema

  schema "field_type" do
    field(:name, :string)
    field(:meta, :map)
    field(:description, :string)
    field(:is_disabled, :boolean, default: true)
    embeds_many(:validations, WraftDoc.Validations.Validation, on_replace: :delete)
    belongs_to(:creator, WraftDoc.Account.User)

    has_many(:fields, WraftDoc.Documents.Field)
    has_many(:organisation_fields, WraftDoc.Documents.OrganisationField)
    timestamps()
  end

  def changeset(%FieldType{} = field_type, attrs \\ %{}) do
    field_type
    |> cast(attrs, [:name, :description, :meta, :is_disabled])
    |> cast_embed(:validations,
      required: true,
      with: &WraftDoc.Validations.Validation.changeset/2
    )
    |> validate_required([:name, :description, :meta])
    |> unique_constraint(:name,
      message: "Field type with the same name exists. Use another name.!",
      name: :field_type_unique_index
    )
  end
end
