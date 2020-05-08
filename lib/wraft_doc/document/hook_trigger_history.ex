defmodule WraftDoc.Document.Pipeline.HookTriggerHistory do
  @moduledoc """
  The pipeline hook trigger history model.
  """
  alias __MODULE__
  use Ecto.Schema
  import Ecto.Changeset

  schema "hook_trigger_history" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    field(:meta, :map)
    belongs_to(:pipeline, WraftDoc.Document.Pipeline)

    timestamps()
  end

  def changeset(%HookTriggerHistory{} = trigger, attrs \\ %{}) do
    trigger
    |> cast(attrs, [:meta])
    |> validate_required([:meta])
  end
end
