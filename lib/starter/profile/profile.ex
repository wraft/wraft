defmodule Starter.ProfileManagement.Profile do
    @moduledoc """
    This is the Profile model
    """ 
    use Ecto.Schema
    import Ecto.Changeset

    schema "basic_profile" do
        field :firstname, :string
        field :lastname, :string
        field :profile_pic, :string
        field :dob, :string
        field :gender, :string
        field :marital_status, :string
        field :current_location, :string
        field :address, :string
        field :pin, :string
        belongs_to :user, Starter.UserManagement.User
        belongs_to :country, Starter.ProfileManagement.Country

        timestamps()
    end

    def changeset(profile, attrs \\ %{}) do
        profile
        |> cast(attrs, [:firstname, :lastname, :profile_pic, :dob, :gender, :marital_status, 
                :current_location, :address, :pin])
        |> validate_required([:firstname, :lastname])
        |> validate_format(:firstname, ~r/^[A-z ]+$/)
        |> validate_format(:lastname, ~r/^[A-z ]+$/)
        |> validate_length(:firstname, min: 2)
    end
end