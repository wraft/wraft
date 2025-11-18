defmodule WraftDoc.Workflows.WorkflowCredential do
  @moduledoc """
  WorkflowCredential schema - stores encrypted credentials for adaptors.
  """
  use WraftDoc.Schema

  alias WraftDoc.EctoType.EncryptedBinaryType

  schema "workflow_credentials" do
    field(:name, :string)
    field(:adaptor_type, :string)
    field(:credentials_encrypted, EncryptedBinaryType)
    field(:metadata, :map, default: %{})

    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:creator, WraftDoc.Account.User)

    has_many(:jobs, WraftDoc.Workflows.WorkflowJob, foreign_key: :credentials_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [
      :name,
      :adaptor_type,
      :credentials_encrypted,
      :metadata,
      :organisation_id,
      :creator_id
    ])
    |> validate_required([
      :name,
      :adaptor_type,
      :credentials_encrypted,
      :organisation_id,
      :creator_id
    ])
    |> unique_constraint([:name, :organisation_id], name: :workflow_credentials_name_org_unique)
  end
end
