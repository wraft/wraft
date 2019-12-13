defmodule ExStarter.UserManagement.User do
  @moduledoc """
  The user model.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "user" do
    field(:name, :string)
    field(:email, :string)
    field(:mobile, :string)
    field(:encrypted_password, :string)
    field(:password, :string, virtual: true)
    field(:country, :string, virtual: true)
    field(:email_verify, :boolean, default: false)
    has_one(:basic_profile, ExStarter.ProfileManagement.Profile)
    belongs_to(:role, ExStarter.UserManagement.Role)

    timestamps()
  end

  @required_fields ~w(name email mobile password country)
  @optional_fields ~w(encrypted_password)
  def changeset(users, attrs \\ %{}) do
    users
    |> cast(attrs, @required_fields, @optional_fields)
    |> validate_required([:name, :email, :mobile, :password, :country])
    |> validate_format(:email, ~r/@/)
    |> validate_format(:name, ~r/^[A-z ]+$/)
    |> validate_length(:name, min: 2)
    |> validate_length(:password, min: 8, max: 16)
    |> unique_constraint(:email, message: "Email already taken.! Try another email.")
    |> generate_encrypted_password
  end

  defp generate_encrypted_password(current_changeset) do
    case current_changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(
          current_changeset,
          :encrypted_password,
          Comeonin.Bcrypt.hashpwsalt(password)
        )

      _ ->
        current_changeset
    end
  end
end
