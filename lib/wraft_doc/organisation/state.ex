defmodule WraftDoc.Enterprise.Flow.State do
  @moduledoc """
    The state model.
  """
  use WraftDoc.Schema

  alias __MODULE__
  alias WraftDoc.Account.User
  import Ecto.Query
  @derive {Jason.Encoder, only: [:state]}
  defimpl Spur.Trackable, for: State do
    def actor(state), do: "#{state.creator_id}"
    def object(state), do: "State:#{state.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  schema "state" do
    field(:state, :string, null: false)
    field(:order, :integer, null: false)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:flow, WraftDoc.Enterprise.Flow)

    has_many(:instances, WraftDoc.Document.Instance, foreign_key: :state_id)
    has_many(:pre_states, WraftDoc.Enterprise.ApprovalSystem, foreign_key: :pre_state_id)
    has_many(:post_states, WraftDoc.Enterprise.ApprovalSystem, foreign_key: :post_state_id)
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
    cast(flow, attrs, [:order])
  end
end
