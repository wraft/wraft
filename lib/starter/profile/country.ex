defmodule Starter.Profile_management.Country do
    @moduledoc """
    This is the Country module
    """
    use Ecto.Schema
    import Ecto.Changeset
    alias Starter.User_management.Roles

    schema "countries" do
        field :country_name, :string
        field :country_code, :string
        field :calling_code, :string
        has_many :basic_profiles, Starter.Profile_management.Profile
    end
end