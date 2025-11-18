defmodule WraftDoc.Workflows.WorkflowRunLog do
  @moduledoc """
  WorkflowRunLog schema - structured logs for workflow runs and jobs.
  """
  use WraftDoc.Schema

  schema "workflow_run_logs" do
    field(:level, :string)
    field(:message, :string)
    field(:metadata, :map, default: %{})
    field(:timestamp, :utc_datetime)

    belongs_to(:run, WraftDoc.Workflows.WorkflowRun)
    belongs_to(:run_job, WraftDoc.Workflows.WorkflowRunJob)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:level, :message, :metadata, :timestamp, :run_id, :run_job_id])
    |> validate_required([:level, :message, :timestamp, :run_id])
  end
end
