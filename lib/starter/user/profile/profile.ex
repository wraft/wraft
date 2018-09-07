defmodule Starter.ProfileManagement.Profile do
    @moduledoc """
    This is the Profile model
    """ 
    use Ecto.Schema
    use Arc.Ecto.Schema
    import Ecto.Changeset
require IEx
    schema "basic_profile" do
        field :firstname, :string
        field :lastname, :string
        field :profile_pic, StarterWeb.PropicUploader.Type
        field :dob, :date
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
        |> cast(attrs, [:firstname, :lastname, :dob, :gender, :marital_status, 
                :current_location, :address, :pin])
        |> cast_attachments(attrs, [:profile_pic])
        |> validate_required([:firstname, :lastname])
        |> validate_format(:firstname, ~r/^[A-z ]+$/)
        |> validate_format(:lastname, ~r/^[A-z ]+$/)
        |> validate_length(:firstname, min: 2)
        |> validate_dob
        
    end

    defp validate_dob(current_changeset) do
        
        if Enum.member?(current_changeset.changes, "dob") do
            # dob = current_changeset.changes.dob 
            {:ok, dob} = Timex.parse(current_changeset.changes.dob, "{YYYY}-{M}-{D}")
            age = Timex.diff(Timex.now, dob, :years) 
            if  age > 16 do
            current_changeset
            |> put_change(:dob, dob)
            else
            add_error(current_changeset, :dob, "You are not old enough to use or services, sorry.!")
            end   
        else 
            current_changeset
        end
    end
end