defmodule WraftDoc.Account.RoleGroup do
  @moduledoc """
  Role group schema
  """

  use WraftDoc.Schema

  schema "role_group" do
    field(:name, :string)
    field(:description, :string)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    has_many(:group_roles, WraftDoc.Account.GroupRole)
    has_many(:roles, through: [:group_roles, :roles])
    timestamps()
  end

  def changeset(role_group, attrs \\ %{}) do
    role_group
    |> cast(attrs, [:name, :description, :organisation_id])
    |> validate_required([:name, :organisation_id])
  end
end
