defmodule WraftDoc.CounterParties.PartyType do
  @moduledoc """
    This module manages party types for counter parties.

    Party types represent categories of signatories (external, vendor, current_org).
    Each party type has a sign_order that determines the sequence in which different
    types of parties should sign documents. This is separate from the individual
    counterparty's sign_order, which determines the sequence within a party type.
  """
  use WraftDoc.Schema

  schema "party_types" do
    field(:name, :string)
    field(:sign_order, :integer)
    has_many(:counter_parties, WraftDoc.CounterParties.CounterParty)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(party_type, attrs) do
    party_type
    |> cast(attrs, [:name, :sign_order, :organisation_id])
    |> validate_required([:name, :sign_order])
    |> validate_number(:sign_order, greater_than: 0)
    |> unique_constraint([:name, :organisation_id],
      message: "Party type name must be unique within an organisation"
    )
  end
end
