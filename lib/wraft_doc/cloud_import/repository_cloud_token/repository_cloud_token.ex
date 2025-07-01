defmodule WraftDoc.CloudImport.RepositoryCloudToken do
  @moduledoc """
  Schema for Cloud Auth Tokens
  """
  use WraftDoc.Schema
  alias WraftDoc.EctoType.EncryptedBinaryType

  @provider_types [
    :google_drive,
    :dropbox,
    :onedrive
  ]
  schema "repository_cloud_tokens" do
    field(:provider, Ecto.Enum, values: @provider_types)
    field(:expires_at, :utc_datetime)
    field(:refresh_token, EncryptedBinaryType)
    field(:access_token, EncryptedBinaryType)
    field(:external_user_data, :map, default: %{})
    field(:meta_data, :map, default: %{})
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation, type: :binary_id)
    belongs_to(:user, WraftDoc.Account.User, type: :binary_id)

    timestamps()
  end

  def changeset(repo_cloud_token, attrs \\ %{}) do
    repo_cloud_token
    |> cast(attrs, [
      :refresh_token,
      :access_token,
      :provider,
      :external_user_data,
      :expires_at,
      :meta_data,
      :user_id,
      :organisation_id
    ])
    |> validate_required([:refresh_token, :access_token, :user_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:organisation_id)
  end
end
