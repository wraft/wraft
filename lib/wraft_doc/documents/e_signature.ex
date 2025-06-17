defmodule WraftDoc.Documents.ESignature do
  @moduledoc """
  Schema for managing electronic signatures for documents
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  alias WraftDoc.Account.User
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Enterprise.Organisation

  @signature_types [:digital, :electronic, :handwritten]

  schema "e_signature" do
    field(:signed_file, :string)
    field(:signature_type, Ecto.Enum, values: @signature_types, default: :electronic)
    field(:signature_data, :map, default: %{})
    field(:signature_position, :map, default: %{})
    field(:signature_date, :utc_datetime)
    field(:verification_token, :string)
    field(:ip_address, :string)
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
    |> unique_constraint(:content_id,
      name: :e_signature_content_id_counter_party_id_index,
      message: "Signature already exists for this document and counterparty"
    )
    |> unique_constraint(:verification_token,
      name: :e_signature_verification_token_index,
      message: "Verification token already exists"
    )
  end
end
