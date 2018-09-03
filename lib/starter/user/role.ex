defmodule Starter.User_management.Roles do
    @moduledoc """
    This is the Roles module
    """
    use Ecto.Schema
    import Ecto.Changeset
    alias Starter.User_management.Roles

    schema "roles" do
        field :name, :string
        field :admin, :boolean, default: false
        has_many :users, Starter.User_management.User

        timestamps()
    end

    def changeset(%Roles{} = role, attrs \\ %{}) do
        role
        |> cast(attrs, [:name, :admin])
        |> validate_required([:name, :admin])
    end    
end