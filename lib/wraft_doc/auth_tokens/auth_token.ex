defmodule WraftDoc.AuthTokens.AuthToken do
  @moduledoc """
    The AuthToken schema.
  """

  use WraftDoc.Schema

  @type t :: %__MODULE__{}
  @token_types [
    :password_verify,
    :invite,
    :email_verify,
    :set_password,
    :delete_organisation,
    :document_invite
  ]

  schema "auth_token" do
    field(:value, :string)
    field(:token_type, Ecto.Enum, values: @token_types)
    field(:expiry_datetime, :naive_datetime)
    belongs_to(:user, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(token, attrs \\ %{}) do
    token
    |> cast(attrs, [:value, :token_type, :user_id, :expiry_datetime])
    |> validate_required([:value, :token_type])
  end
end
