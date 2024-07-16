defmodule WraftDoc.Account.UserRole do
  @moduledoc """
    This is the UserRole module
  """
  use WraftDoc.Schema
  alias WraftDoc.Account.{Role, User}

  schema "user_role" do
    belongs_to(:user, User)
    belongs_to(:role, Role)

    timestamps()
  end

  def changeset(user_role, attrs \\ %{}) do
    user_role
    |> cast(attrs, [:user_id, :role_id])
    |> validate_required([:user_id, :role_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:role_id)
    |> unique_constraint(:user_id,
      message: "user with the role already exist.!",
      name: :user_role_unique_index
    )
  end
end
