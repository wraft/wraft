defmodule WraftDoc.CloudImport.CloudAuthToken do
  @moduledoc """
  Schema for Cloud Auth Tokens
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :service,
             :expires_at,
             :refresh_token,
             :access_token,
             :meta_data
           ]}
  @service_types [
    :google_drive,
    :dropbox,
    :onedrive
  ]
  schema "cloud_auth_tokens" do
    field(:service, Ecto.Enum, values: @service_types)
    field(:expires_at, :utc_datetime)
    field(:refresh_token, :string)
    field(:access_token, :string)
    field(:meta_data, :map, default: %{})
    belongs_to(:user, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(cloud_auth_token, attrs \\ %{}) do
    cloud_auth_token
    |> cast(attrs, [:refresh_token, :access_token, :meta_data])
    |> validate_required([:refresh_token, :access_token])
  end
end
