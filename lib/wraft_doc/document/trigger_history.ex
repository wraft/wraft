defmodule WraftDoc.Document.Pipeline.TriggerHistory do
  @moduledoc """
  The pipeline trigger history model.
  """
  alias __MODULE__
  use Ecto.Schema
  import Ecto.Changeset
  @derive {Jason.Encoder, only: [:uuid, :data, :meta, :state, :pipeline_id, :creator_id]}
  def states, do: [enqued: 1, executing: 2, pending: 3, success: 4, failed: 5]

  schema "trigger_history" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    field(:data, :map)
    field(:meta, :map)
    field(:state, :integer)
    belongs_to(:pipeline, WraftDoc.Document.Pipeline)
    belongs_to(:creator, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(%TriggerHistory{} = trigger, attrs \\ %{}) do
    trigger
    |> cast(attrs, [:data, :state, :creator_id])
    |> validate_required([:data, :state, :creator_id])
  end

  def hook_changeset(%TriggerHistory{} = trigger, attrs \\ %{}) do
    trigger
    |> cast(attrs, [:data, :state])
    |> validate_required([:data, :state])
  end

  def update_changeset(%TriggerHistory{} = trigger, attrs \\ %{}) do
    trigger
    |> cast(attrs, [:meta, :state])
    |> validate_required([:state])
  end
end
