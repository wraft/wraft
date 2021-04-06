defmodule WraftDoc.Enterprise.OrganisationRole do
  @moduledoc """
    This is the OrganisationRole module
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Account.Role

  schema "organisation_role" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    belongs_to(:organisation, Organisation)
    belongs_to(:role, Role)

    timestamps()
  end

  def changeset(organisation_role, attrs \\ %{}) do
    organisation_role
    |> cast(attrs, [:organisation_id, :role_id])
    |> validate_required([:role_id])
  end
end
