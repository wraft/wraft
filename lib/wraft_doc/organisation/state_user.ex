defmodule WraftDoc.Enterprise.StateUser do
  @moduledoc """
  Schema connecting the users with their organisations
  """
  use WraftDoc.Schema

  @fields [:state_id, :user_id]

  schema "state_users" do
    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:state, WraftDoc.Enterprise.Flow.State)
    belongs_to(:content, WraftDoc.Documents.Instance)
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

  def add_document_level_user_changeset(%__MODULE__{} = state_users, params \\ %{}) do
    state_users
    |> cast(params, @fields ++ [:content_id])
    |> validate_required(@fields ++ [:content_id])
    |> unique_constraint(@fields,
      name: :state_users_state_id_user_id_index,
      message: "already exist"
    )
    |> unique_constraint(@fields ++ [:content_id],
      name: "state_users_state_id_user_id_content_id_index",
      message: "already exist"
    )
    |> foreign_key_constraint(:state_id, message: "Please enter an existing state")
    |> foreign_key_constraint(:user_id, message: "Please enter a valid user")
    |> foreign_key_constraint(:content_id, message: "Please enter a valid document")
  end
end
