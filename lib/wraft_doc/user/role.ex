defmodule WraftDoc.Account.Role do
  @moduledoc """
    This is the Roles module
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Enterprise.OrganisationRole

  schema "role" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string)
    has_many(:organisation_roles, OrganisationRole)
    has_many(:organisations, through: [:organisation_roles, :organisation])
    has_many(:permissions, WraftDoc.Authorization.Permission)
    has_many(:user_roles, WraftDoc.Account.UserRole)
    has_many(:users, through: [:user_roles, :user])

    timestamps()
  end

  def changeset(role, attrs \\ %{}) do
    role
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:role, message: "Role already exists")
  end
end
