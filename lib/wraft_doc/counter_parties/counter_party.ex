defmodule WraftDoc.CounterParties.CounterParty do
  @moduledoc """
    This is the Counter Parties module
  """
  use WraftDoc.Schema

  # TODO need to improve
  schema "counter_parties" do
    field(:name, :string)
    belongs_to(:content, WraftDoc.Document.Instance)
    timestamps()
  end

  def changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [:name, :content_id])
    |> validate_required([:name, :content_id])
  end
end
