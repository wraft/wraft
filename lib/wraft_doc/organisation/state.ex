defmodule WraftDoc.Enterprise.Flow.State do
  @moduledoc """
    The state model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "state" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:state, :string, null: false)
    field(:order, :integer, null: false)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:flow, WraftDoc.Enterprise.Flow)

    has_many(:instances, WraftDoc.Document.Instance, foreign_key: :state_id)
    timestamps()
  end

  def changeset(%State{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:state, :order, :organisation_id])
    |> validate_required([:state, :order, :organisation_id])
    |> unique_constraint(:state,
      message: "State already created.!",
      name: :flow_state_unique_index
    )
  end

  def order_update_changeset(%State{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:order])
  end
end
