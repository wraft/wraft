defmodule WraftDoc.Models.Model do
  @moduledoc """
  Model schema for AI models.
  """

  use WraftDoc.Schema
  import Ecto.Changeset

  alias WraftDoc.Account.User
  alias WraftDoc.EctoType.EncryptedBinaryType
  alias WraftDoc.Enterprise.Organisation

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "ai_model" do
    field(:name, :string)
    field(:status, :string)
    field(:auth_key, EncryptedBinaryType)
    field(:description, :string)
    field(:provider, :string)
    field(:endpoint_url, :string)
    field(:is_default, :boolean, default: false)
    field(:is_local, :boolean, default: false)
    field(:is_thinking_model, :boolean, default: false)
    field(:daily_request_limit, :integer)
    field(:daily_token_limit, :integer)
    field(:model_name, :string)
    field(:model_type, :string)
    field(:model_version, :string)

    belongs_to(:creator, User)
    belongs_to(:organisation, Organisation)

    timestamps()
  end

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [
      :name,
      :description,
      :provider,
      :endpoint_url,
      :is_default,
      :is_local,
      :is_thinking_model,
      :daily_request_limit,
      :daily_token_limit,
      :auth_key,
      :status,
      :creator_id,
      :organisation_id,
      :model_name,
      :model_type,
      :model_version
    ])
    |> validate_required([
      :name,
      :description,
      :provider,
      :is_default,
      :is_local,
      :is_thinking_model,
      :daily_request_limit,
      :daily_token_limit,
      :auth_key,
      :status,
      :model_name,
      :model_type,
      :model_version,
      :creator_id,
      :organisation_id
    ])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:status, ["active", "inactive", "pending"])
    |> validate_url(:endpoint_url)
    |> unique_constraint(:name, name: :ai_model_organisation_id_name_index)
    |> unique_constraint(:model_name, name: :ai_model_organisation_id_model_name_index)
    |> unique_constraint(:is_default,
      name: :unique_default_model_per_organisation,
      message: "Only one default model is allowed per organisation"
    )
    |> foreign_key_constraint(:creator_id)
    |> foreign_key_constraint(:organisation_id)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn field, value ->
      uri = URI.parse(value)

      if uri.scheme in ["http", "https"] and uri.host do
        []
      else
        [{field, "must be a valid HTTP/HTTPS URL"}]
      end
    end)
  end
end
