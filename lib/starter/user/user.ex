defmodule Starter.User_management.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:name, :string)
    field(:email, :string)
    field(:encrypted_password, :string)
    field(:password, :string, virtual: true)
    timestamps()
  end

  @required_fields ~w(name email password)
  @optional_fields ~w(encrypted_password)
  def changeset(users, attrs \\ %{}) do
    users
    |> cast(attrs, @required_fields, @optional_fields)
    |> validate_required([:name, :email, :password])
    |> validate_format(:email, ~r/@/)
    |> validate_format(:name, ~r/^[A-z]+$/)
    |> validate_length(:name, min: 2)
    |> validate_length(:password, min: 8, max: 16)
    |> validate_confirmation(:password, message: "Passwords do not match.!")
    |> unique_constraint(:email, message: "Email already taken.! Try another email.")
    |> generate_encrypted_password
  end

  defp generate_encrypted_password(current_changeset) do
      case current_changeset do
          %Ecto.Changeset{valid?: true, changes: %{password: password}} -> 
            put_change current_changeset,
            :encrypted_password,
            Comeonin.Bcrypt.hashpwsalt(password)
          _->
            current_changeset
      end
  end
end
