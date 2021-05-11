defmodule WraftDoc.Enterprise.Flow do
  @moduledoc """
    The work flow model.
  """
  use WraftDoc.Schema

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
    field(:name, :string, null: false)
    field(:controlled, :boolean, default: false)
    field(:control_data, :map)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    has_many(:states, WraftDoc.Enterprise.Flow.State)
    has_many(:approval_systems, through: [:states, :pre_states])
    timestamps()
  end

  def changeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:name, :controlled, :organisation_id])
    |> validate_required([:name, :organisation_id])
    |> unique_constraint(:name,
      message: "Flow already created.!",
      name: :flow_organisation_unique_index
    )
  end

  def controlled_changeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:name, :controlled, :control_data, :organisation_id])
    |> validate_required([:name, :controlled, :control_data, :organisation_id])
    |> unique_constraint(:name,
      message: "Flow already created.!",
      name: :flow_organisation_unique_index
    )
  end

  def update_changeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:name, :organisation_id])
    |> validate_required([:name, :organisation_id])
    |> unique_constraint(:name,
      message: "Flow already created.!",
      name: :flow_organisation_unique_index
    )
  end

  def update_controlled_changeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:name, :control_data, :organisation_id])
    |> validate_required([:name, :control_data, :organisation_id])
    |> unique_constraint(:name,
      message: "Flow already created.!",
      name: :flow_organisation_unique_index
    )
  end
end
