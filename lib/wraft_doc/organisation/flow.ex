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
    timestamps()
  end

  def chanegeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:state, :order, :organisation_id])
    |> validate_required([:state, :order, :organisation_id])
    |> unique_constraint(:state,
      message: "State already created.!",
      name: :flow_organisation_unique_index
    )
  end
end
