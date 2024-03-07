defmodule WraftDoc.Enterprise.Flow.State do
  @moduledoc """
    The state model.
  """
  use WraftDoc.Schema

  alias __MODULE__

  schema "state" do
    field(:state, :string)
    field(:order, :integer)

    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:flow, WraftDoc.Enterprise.Flow)
    has_many(:instances, WraftDoc.Document.Instance, foreign_key: :state_id)
    has_many(:content_collab, WraftDoc.Document.ContentCollab)
    many_to_many(:approvers, WraftDoc.Account.User, join_through: "state_users")
    timestamps()
  end

  def changeset(%State{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:state, :order, :organisation_id, :flow_id])
    |> validate_required([:state, :order, :organisation_id, :flow_id])
    |> unique_constraint(:state,
      message: "State already created.!",
      name: :flow_state_unique_index
    )
    |> unique_constraint(:order,
      message: "Order already exists.!",
      name: :state_order_flow_id_index
    )
  end

  def order_update_changeset(%State{} = flow, attrs \\ %{}) do
    cast(flow, attrs, [:order])
  end
end
