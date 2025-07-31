defmodule WraftDoc.Account.UserOrganisation do
  @moduledoc """
  Schema connecting the users with their organisations
  """
  use WraftDoc.Schema

  @fields [:user_id, :organisation_id, :deleted_at]

  schema "users_organisations" do
    field(:deleted_at, :naive_datetime)

    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(users_organisations, params \\ %{}) do
    users_organisations
    |> cast(params, @fields)
    |> validate_required([:user_id, :organisation_id])
    |> unique_constraint([:user_id, :organisation_id],
      name: :users_organisations_organisation_id_user_id_index,
      message: "already exist"
    )
    |> foreign_key_constraint(:user_id, message: "Please enter an existing user")
    |> foreign_key_constraint(:organisation_id, message: "Please enter a valid organisation")
  end

  def delete_changeset(users_organisations, attrs \\ %{}) do
    users_organisations
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
  end

  def update_changeset(users_organisations, attrs \\ %{}) do
    cast(users_organisations, attrs, [:deleted_at])
  end
end
