defmodule WraftDoc.Account.User do
  @moduledoc """
  The user model.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "user" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string)
    field(:email, :string)
    field(:encrypted_password, :string)
    field(:password, :string, virtual: true)
    field(:email_verify, :boolean, default: false)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:role, WraftDoc.Account.Role)
    has_one(:profile, WraftDoc.Account.Profile)

    has_many(:layouts, WraftDoc.Document.Layout, foreign_key: :creator_id)
    has_many(:content_types, WraftDoc.Document.ContentType, foreign_key: :creator_id)
    has_many(:flows, WraftDoc.Enterprise.Flow, foreign_key: :creator_id)

    timestamps()
  end

  def changeset(users, attrs \\ %{}) do
    users
    |> cast(attrs, [:name, :email, :password, :role_id])
    |> validate_required([:name, :email, :password])
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
          Bcrypt.hash_pwd_salt(password)
        )

      _ ->
        current_changeset
    end
  end
end