defmodule WraftDoc.CloudImport.RepositoryCloudToken do
  @moduledoc """
  Schema for Cloud Auth Tokens
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :provider,
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
  schema "repository_cloud_tokens" do
    field(:provider, Ecto.Enum, values: @service_types)
    field(:expires_at, :utc_datetime)
    field(:refresh_token, :string)
    field(:access_token, :string)
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
