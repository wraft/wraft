defmodule WraftDoc.Enterprise.Flow do
  @moduledoc """
    The work flow model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "flow" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)

    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    has_many(:states, WraftDoc.Enterprise.Flow.State)
    timestamps()
  end

  def changeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:name, :organisation_id])
    |> validate_required([:name, :organisation_id])
    |> unique_constraint(:name,
      message: "Flow already created.!",
      name: :flow_organisation_unique_index
    )
  end
end
