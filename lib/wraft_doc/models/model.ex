defmodule WraftDoc.Models.Model do
  @moduledoc """
  Model schema for AI models.
  """

  use WraftDoc.Schema
  import Ecto.Changeset

  alias WraftDoc.Account.User
  alias WraftDoc.EctoType.EncryptedBinaryType
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Models.Prompt

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "ai_model" do
    field(:name, :string)
    field(:status, :string)
    field(:auth_key, EncryptedBinaryType)
    field(:description, :string)
    field(:provider, :string)
    field(:endpoint_url, :string)
    field(:is_local, :boolean, default: false)
    field(:is_thinking_model, :boolean, default: false)
    field(:daily_request_limit, :integer)
    field(:daily_token_limit, :integer)
    field(:model_name, :string)
    field(:model_type, :string)
    field(:model_version, :string)

    belongs_to(:creator, User)
    belongs_to(:organisation, Organisation)
    has_many(:prompts, Prompt)

    timestamps()
  end

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [
      :name,
      :creator_id,
      :organisation_id,
      :description,
      :provider,
      :endpoint_url,
      :is_local,
      :is_thinking_model,
      :daily_request_limit,
      :daily_token_limit,
      :auth_key,
      :status,
      :model_name,
      :model_type,
      :model_version
    ])
    |> validate_required([
      :name,
      :description,
      :provider,
      :endpoint_url,
      :is_local,
      :is_thinking_model,
      :daily_request_limit,
      :daily_token_limit,
      :auth_key,
      :status,
      :model_name,
      :model_type,
      :model_version
    ])
    |> unique_constraint(:name)
    |> unique_constraint(:model_name)
  end
end
