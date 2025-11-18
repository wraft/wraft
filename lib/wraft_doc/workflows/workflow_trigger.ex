defmodule WraftDoc.Workflows.WorkflowTrigger do
  @moduledoc """
  WorkflowTrigger schema - represents how a workflow can be triggered.
  """
  use WraftDoc.Schema

  @trigger_types ~w(webhook scheduled event manual)a

  schema "workflow_triggers" do
    field(:type, :string)
    field(:is_active, :boolean, default: true)
    field(:config, :map, default: %{})
    field(:secret, :string)

    belongs_to(:workflow, WraftDoc.Workflows.Workflow)

    has_many(:runs, WraftDoc.Workflows.WorkflowRun, foreign_key: :trigger_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(trigger, attrs) do
    trigger
    |> cast(attrs, [:type, :is_active, :config, :secret, :workflow_id])
    |> validate_required([:type, :workflow_id])
    |> validate_inclusion(:type, @trigger_types)
  end
end
