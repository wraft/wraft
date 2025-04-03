defmodule WraftDoc.CounterParties.CounterParty do
  @moduledoc """
    This is the Counter Parties module for managing document signatories
  """
  use WraftDoc.Schema

  schema "counter_parties" do
    field(:name, :string)
    field(:email, :string)
    field(:signature_status, Ecto.Enum, values: [:pending, :signed, :rejected], default: :pending)
    field(:signature_date, :utc_datetime)
    field(:signature_ip, :string)
    belongs_to(:content, WraftDoc.Documents.Instance)
    belongs_to(:guest_user, WraftDoc.Account.User, foreign_key: :guest_user_id)

    timestamps()
  end

  def changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [
      :name,
      :email,
      :content_id,
      :guest_user_id,
      :signature_status,
      :signature_date,
      :signature_ip
    ])
    |> validate_required([:name, :content_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
  end

  def sign_changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [:signature_status, :signature_date, :signature_ip])
    |> validate_required([:signature_status, :signature_date])
  end
end
