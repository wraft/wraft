defmodule Starter.UserManagement.User do
  @moduledoc """
  The user model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  require IEx

  schema "users" do
    field(:firstname, :string)
    field(:lastname, :string)
    field(:email, :string)
    field(:mobile, :string)
    field(:encrypted_password, :string)
    field(:password, :string, virtual: true)
    field(:country, :string, virtual: true)
    field(:mobile_verify, :boolean, default: false)
    field(:email_verify, :boolean, default: false)
    belongs_to :roles, Starter.UserManagement.Roles
    has_one :basic_profile, Starter.ProfileManagement.Profile
    timestamps()
  end

  @required_fields ~w(firstname lastname email mobile password country)
  @optional_fields ~w(encrypted_password)
  def changeset(users, attrs \\ %{}) do
    users
    |> cast(attrs, @required_fields, @optional_fields)
    |> validate_required([:firstname, :lastname, :email, :mobile, :password, :country])
    |> validate_format(:email, ~r/@/)
    |> validate_format(:firstname, ~r/^[A-z ]+$/)
    |> validate_format(:lastname, ~r/^[A-z ]+$/)
    |> validate_length(:firstname, min: 2)
    |> validate_length(:password, min: 8, max: 16)
    |> validate_confirmation(:password, message: "Passwords do not match.!")
    |> unique_constraint(:email, message: "Email already taken.! Try another email.")
    |> unique_constraint(:mobile, message: "Mobile Number already taken.! Try another number.")
    |> validate_mobile
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

  defp validate_mobile(current_changeset) do
    {:ok, phone_number} =
      ExPhoneNumber.parse(current_changeset.changes.mobile, current_changeset.changes.country)

    case ExPhoneNumber.is_possible_number?(phone_number) do
      true ->
        case ExPhoneNumber.is_valid_number?(phone_number) do
          true ->
            current_changeset

          false ->
            add_error(current_changeset, :mobile, "Invalid Mobile number")
        end

      false ->
        add_error(current_changeset, :mobile, "Please check your mobile number and try again.!")
    end
  end
end
