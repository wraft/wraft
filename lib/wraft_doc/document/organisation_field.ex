defmodule WraftDoc.Document.OrganisationField do
  @moduledoc """
  Same as content type field for an organisation to collect data in dependant on content type
  """
  use Ecto.Schema
  use WraftDoc.Schema
  alias WraftDoc.Account.User
  alias WraftDoc.Document.OrganisationField
  @derive {Jason.Encoder, only: [:name]}
  defimpl Spur.Trackable, for: OrganisationField do
    def actor(organisation_field), do: "#{organisation_field.creator_id}"
    def object(organisation_field), do: "OrganisationField:#{organisation_field.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  schema "organisation_field" do
    field(:name, :string)
    field(:description, :string)
    field(:meta, :map)
    belongs_to(:field_type, WraftDoc.Document.FieldType)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:creator, User)

    timestamps()
  end

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
