defmodule WraftDoc.Account.Role do
  @moduledoc """
    This is the Roles module
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Account.Role

  schema "role" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string)

    # has_many(:users, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(%Role{} = role, attrs \\ %{}) do
    role
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:role, message: "Role already exists")
  end
end
