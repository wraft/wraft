defmodule WraftDoc.Document.Instance.ContractMeta do
  @moduledoc """
    The contract document metadata
  """
  use Ecto.Schema
  import Ecto.Changeset

  @contract_fields ~w(type status start_date expiry_date contract_value counter_parties reminder)a
  @contract_status ~w(draft review active expired)a

  @primary_key false
  embedded_schema do
    field(:type, Ecto.Enum, values: [:contract])
    field(:status, Ecto.Enum, values: @contract_status, default: :draft)
    field(:start_date, :date)
    field(:expiry_date, :date)
    field(:contract_value, :decimal)
    field(:counter_parties, {:array, :string}, default: [])
    field(:reminder, {:array, :map}, default: [])
  end

  def changeset(contract_meta, attrs \\ %{}) do
    contract_meta
    |> cast(attrs, @contract_fields)
    |> validate_required(@contract_fields)
  end
end
