defmodule WraftDoc.Enterprise.OrganisationRole do
  @moduledoc """
    This is the OrganisationRole module
  """
  use WraftDoc.Schema
  alias WraftDoc.{Account.Role, Enterprise.Organisation}

  schema "organisation_role" do
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
