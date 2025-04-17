defmodule WraftDoc.Documents.ESignature do
  @moduledoc """
  Schema for managing electronic signatures for documents
  """
  use WraftDoc.Schema

  alias WraftDoc.Account.User
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Enterprise.Organisation

  @signature_types [:digital, :electronic, :handwritten]

  schema "e_signature" do
    field(:api_url, :string)
    field(:body, :string)
    field(:header, :string)
    field(:file, WraftDocWeb.SignatureUploader.Type)
    field(:signed_file, :string)
    field(:signature_type, Ecto.Enum, values: @signature_types, default: :digital)
    field(:signature_data, :map)
    field(:signature_position, :map)
    field(:signature_date, :utc_datetime)
    field(:verification_token, :string)
    field(:is_valid, :boolean, default: false)
    belongs_to(:content, Instance)
    belongs_to(:user, User)
    belongs_to(:organisation, Organisation)
    belongs_to(:counter_party, CounterParty)

    timestamps()
  end

  def changeset(e_signature, attrs \\ %{}) do
    e_signature
    |> cast(attrs, [
      :api_url,
      :body,
      :header,
      :file,
      :signed_file,
      :signature_type,
      :signature_data,
      :signature_position,
      :signature_date,
      :is_valid,
      :verification_token,
      :content_id,
      :user_id,
      :organisation_id,
      :counter_party_id
    ])
    |> validate_required([:content_id, :user_id, :organisation_id])
  end

  def signature_changeset(e_signature, attrs \\ %{}) do
    e_signature
    |> cast(attrs, [
      :signature_data,
      :signature_position,
      :ip_address,
      :signature_date,
      :is_valid,
      :signed_file
    ])
    |> validate_required([:signature_data, :signature_date, :ip_address])
  end

  def verification_changeset(e_signature, attrs \\ %{}) do
    e_signature
    |> cast(attrs, [:is_valid, :verification_token])
    |> validate_required([:is_valid])
  end
end
