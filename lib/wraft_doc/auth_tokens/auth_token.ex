defmodule WraftDoc.AuthTokens.AuthToken do
  @moduledoc """
    The AuthToken schema.
  """

  use WraftDoc.Schema

  @type t :: %__MODULE__{}

  schema "auth_token" do
    field(:value, :string)

    field(:token_type, Ecto.Enum,
      values: [:password_verify, :invite, :email_verify, :set_password]
    )

    field(:expiry_datetime, :naive_datetime)
    belongs_to(:user, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(token, attrs \\ %{}) do
    token
    |> cast(attrs, [:value, :token_type, :user_id])
    |> validate_required([:value, :token_type])
  end
end
