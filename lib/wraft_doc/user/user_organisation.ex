defmodule WraftDoc.Account.UserOrganisation do
  @moduledoc """
  Schema connecting the users with their organisations
  """
  use WraftDoc.Schema

  @fields [:user_id, :organisation_id]

  schema "users_organisations" do
    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(users_organisations, params \\ %{}) do
    users_organisations
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> unique_constraint(@fields,
      name: :users_organisations_organisation_id_user_id_index,
      message: "already exist"
    )
    |> foreign_key_constraint(:user_id, message: "Please enter an existing user")
    |> foreign_key_constraint(:organisation_id, message: "Please enter a valid organisation")
  end
end
