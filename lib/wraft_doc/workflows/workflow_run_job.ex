defmodule WraftDoc.Workflows.WorkflowRunJob do
  @moduledoc """
  WorkflowRunJob schema - represents execution of a single job within a run.
  """
  use WraftDoc.Schema

  schema "workflow_run_jobs" do
    field(:state, :string)
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)
    field(:duration_ms, :integer)
    field(:input_data, :map, default: %{})
    field(:output_data, :map)
    field(:error, :map)
    field(:retry_count, :integer, default: 0)

    belongs_to(:run, WraftDoc.Workflows.WorkflowRun)
    belongs_to(:job, WraftDoc.Workflows.WorkflowJob)

    timestamps(type: :utc_datetime)
  end

  def changeset(run_job, attrs) do
    run_job
    |> cast(attrs, [
      :state,
      :started_at,
      :completed_at,
      :duration_ms,
      :input_data,
      :output_data,
      :error,
      :retry_count,
      :run_id,
      :job_id
    ])
    |> validate_required([:state, :run_id, :job_id])
  end
end
