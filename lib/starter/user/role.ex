defmodule Starter.UserManagement.Role do
    @moduledoc """
    This is the Roles module
    """
    use Ecto.Schema
    import Ecto.Changeset
    alias Starter.UserManagement.Role

    schema "roles" do
        field :name, :string
        field :admin, :boolean, default: false
        has_many :users, Starter.UserManagement.User

        timestamps()
    end

    def changeset(%Role{} = role, attrs \\ %{}) do
        role
        |> cast(attrs, [:name, :admin])
        |> validate_required([:name, :admin])
    end    
end