defmodule WraftDoc.Account.UserRole do
  @moduledoc """
    This is the UserRole module
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Account.{Role, User}

  schema "user_role" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    belongs_to(:user, User)
    belongs_to(:role, Role)

    timestamps()
  end

  def changeset(user_role, attrs \\ %{}) do
    user_role
    |> cast(attrs, [:user_id, :role_id])
    |> validate_required([:user_id, :role_id])
  end
end
