defmodule WraftDoc.Documents.OrganisationField do
  @moduledoc """
  Same as content type field for an organisation to collect data in dependant on content type
  """
  use WraftDoc.Schema
  alias WraftDoc.Documents.FieldType

  schema "organisation_field" do
    field(:name, :string)
    field(:description, :string)
    field(:meta, :map)
    belongs_to(:field_type, FieldType)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:creator, WraftDoc.Account.User)

    timestamps()
  end

  # TODO write tests for the below changesets
  @doc false
  def changeset(organisation_field, attrs \\ %{}) do
    organisation_field
    |> cast(attrs, [:name, :meta, :description, :field_type_id, :organisation_id, :creator_id])
    |> validate_required([:name, :field_type_id, :organisation_id, :creator_id])
  end

  def update_changeset(organisation_field, attrs \\ %{}) do
    organisation_field
    |> cast(attrs, [:name, :meta, :description, :field_type_id, :organisation_id, :creator_id])
    |> validate_required([:name])
  end
end
