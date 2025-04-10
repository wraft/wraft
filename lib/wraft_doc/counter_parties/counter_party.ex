defmodule WraftDoc.CounterParties.CounterParty do
  @moduledoc """
    This is the Counter Parties module for managing document signatories
  """
  use WraftDoc.Schema

  @signature_status [:pending, :accepted, :signed, :rejected]

  schema "counter_parties" do
    field(:name, :string)
    field(:email, :string)
    field(:signature_status, Ecto.Enum, values: @signature_status, default: :pending)
    field(:signature_date, :utc_datetime)
    field(:signature_ip, :string)
    has_one(:e_signature, WraftDoc.Documents.ESignature)
    belongs_to(:content, WraftDoc.Documents.Instance)
    belongs_to(:user, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [
      :name,
      :email,
      :content_id,
      :user_id,
      :signature_status,
      :signature_date,
      :signature_ip
    ])
    |> validate_required([:name, :content_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
  end

  def update_status_changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [:signature_status])
    |> validate_required([:signature_status])
  end

  def sign_changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [:signature_status, :signature_date, :signature_ip])
    |> validate_required([:signature_status, :signature_date])
  end
end
