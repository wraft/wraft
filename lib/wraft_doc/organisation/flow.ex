defmodule WraftDoc.Enterprise.Flow do
  @moduledoc """
    The work flow model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias WraftDoc.Account.User
  import Ecto.Query
  @derive {Jason.Encoder, only: [:name]}
  defimpl Spur.Trackable, for: Flow do
    def actor(flow), do: "#{flow.creator_id}"
    def object(flow), do: "Flow:#{flow.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

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
