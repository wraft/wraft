defmodule Starter.ProfileManagement.Country do
    @moduledoc """
    This is the Country module
    """
    use Ecto.Schema
    import Ecto.Changeset
    alias Starter.UserManagement.Roles

    schema "countries" do
        field :country_name, :string
        field :country_code, :string
        field :calling_code, :string
        has_many :basic_profiles, Starter.ProfileManagement.Profile
    end

    def changeset(country, attrs \\ %{}) do
        country
        |> cast(attrs, [:country_name, :country_code, :calling_code])
        |> validate_required([:country_name, :country_code, :calling_code])
    end
end