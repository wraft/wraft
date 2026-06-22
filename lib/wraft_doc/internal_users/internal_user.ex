defmodule WraftDoc.InternalUsers.InternalUser do
  @moduledoc """
  Schema for internal users.
  """
  use WraftDoc.Schema

  schema "internal_user" do
    field(:email, :string)
    field(:password, :string, virtual: true)
    field(:encrypted_password, :string)
    field(:is_deactivated, :boolean, default: false)
    field(:session_epoch, :integer, default: 0)

    timestamps()
  end

  def changeset(internal_user, attrs \\ %{}) do
    internal_user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "has invalid format")
    |> validate_length(:password, min: 12, max: 72)
    |> unique_constraint(:email, message: "Email already taken.! Try another email.")
    |> generate_encrypted_password
  end

  def update_changeset(internal_user, attrs \\ %{}) do
    internal_user
    |> cast(attrs, [:email, :password, :is_deactivated])
    |> validate_required([:email, :is_deactivated])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "has invalid format")
    |> validate_length(:password, min: 12, max: 72)
    |> unique_constraint(:email, message: "Email already taken.! Try another email.")
    |> bump_session_epoch()
    |> generate_encrypted_password
  end

  defp bump_session_epoch(changeset) do
    revoke? =
      get_change(changeset, :password) != nil or get_change(changeset, :is_deactivated) == true

    if revoke? do
      put_change(changeset, :session_epoch, (get_field(changeset, :session_epoch) || 0) + 1)
    else
      changeset
    end
  end
end
