defmodule WraftDoc.Account.AuthToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "auth_token" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:value, :string)
    field(:token_type, :string)
    field(:expiry_datetime, :naive_datetime)
    belongs_to(:user, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(token, attrs \\ %{}) do
    token
    |> cast(attrs, [:value, :token_type, :user_id])
    |> validate_required([:value, :token_type])
  end

  # Not used anywhere
  def verification_changeset(token, attrs \\ %{}) do
    token
    |> cast(attrs, [:value, :token_type, :expiry_datetime])
    |> validate_required([:value, :token_type, :expiry_datetime])
  end
end
