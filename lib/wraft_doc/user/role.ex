defmodule WraftDoc.Account.Role do
  @moduledoc """
    This is the Roles module
  """
  use WraftDoc.Schema

  schema "role" do
    field(:name, :string)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    has_many(:permissions, WraftDoc.Authorization.Permission)
    has_many(:user_roles, WraftDoc.Account.UserRole)
    has_many(:users, through: [:user_roles, :user])
    has_many(:content_type_roles, WraftDoc.Document.ContentTypeRole)
    has_many(:content_types, through: [:content_type_roles, :content_type])
    timestamps()
  end

  def changeset(role, attrs \\ %{}) do
    role
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end

  def organisation_changeset(role, attrs \\ %{}) do
    role
    |> cast(attrs, [:organisation_id, :name])
    |> validate_required([:name, :organisation_id])
    |> validate_exclusion(:name, ~w(admin super_admin))
    |> unique_constraint(:name, message: "Role exist in this organisation")
  end
end
