defmodule WraftDoc.Account.RoleGroup do
  @moduledoc """
  Role group schema
  """

  use WraftDoc.Schema
  alias WraftDoc.Account.GroupRole

  schema "role_group" do
    field(:name, :string)
    field(:description, :string)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    has_many(:group_roles, GroupRole)
    has_many(:roles, through: [:group_roles, :role])
    timestamps()
  end

  def changeset(role_group, attrs \\ %{}) do
    role_group
    |> cast(attrs, [:name, :description, :organisation_id])
    |> validate_required([:name, :organisation_id])
    |> cast_assoc(:group_roles, with: &GroupRole.changeset/2)
  end

  def update_changeset(role_group, attrs \\ %{}) do
    role_group
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> cast_assoc(:group_roles, with: &GroupRole.changeset/2)
  end
end
