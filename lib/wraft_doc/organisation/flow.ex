defmodule WraftDoc.Enterprise.Flow do
  @moduledoc """
    The work flow model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Enterprise.Flow

  schema "flow" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:state, :string, null: false)
    field(:order, :integer, null: false)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    has_many(:instances, WraftDoc.Document.Instance, foreign_key: :state_id)
    timestamps()
  end

  def changeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:state, :order])
    |> validate_required([:state, :order])
    |> unique_constraint(:state,
      message: "State already created.!",
      name: :flow_organisation_unique_index
    )
  end

  def order_update_changeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:order])
  end
end