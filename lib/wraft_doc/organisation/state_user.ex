defmodule WraftDoc.Enterprise.StateUser do
  @moduledoc """
  Schema connecting the users with their organisations
  """
  use WraftDoc.Schema

  @fields [:state_id, :user_id]

  schema "state_users" do
    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:state, WraftDoc.Enterprise.Flow.State)
    timestamps()
  end

  def changeset(state_users, params \\ %{}) do
    state_users
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> unique_constraint(@fields,
      name: :state_users_state_id_user_id_index,
      message: "already exist"
    )
    |> foreign_key_constraint(:state_id, message: "Please enter an existing state")
    |> foreign_key_constraint(:user_id, message: "Please enter a valid user")
  end
end
