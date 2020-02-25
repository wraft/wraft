defmodule WraftDoc.Account.Role do
  @moduledoc """
    This is the Roles module
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Account.Role

  schema "role" do
    field(:name, :string)
    has_many(:users, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(%Role{} = role, attrs \\ %{}) do
    role
    |> cast(attrs, [:name, :admin])
    |> validate_required([:name, :admin])
  end
end
