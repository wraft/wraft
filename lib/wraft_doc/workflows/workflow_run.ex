defmodule WraftDoc.Workflows.WorkflowRun do
  @moduledoc """
  WorkflowRun schema - represents an execution of a workflow.
  """
  use WraftDoc.Schema

  schema "workflow_runs" do
    field(:state, :string)
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)
    field(:duration_ms, :integer)
    field(:input_data, :map, default: %{})
    field(:output_data, :map)
    field(:error, :map)

    belongs_to(:workflow, WraftDoc.Workflows.Workflow)
    belongs_to(:trigger, WraftDoc.Workflows.WorkflowTrigger)

    has_many(:run_jobs, WraftDoc.Workflows.WorkflowRunJob, foreign_key: :run_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :state,
      :started_at,
      :completed_at,
      :duration_ms,
      :input_data,
      :output_data,
      :error,
      :workflow_id,
      :trigger_id
    ])
    |> validate_required([:state, :workflow_id])
  end
end
