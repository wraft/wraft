defmodule WraftDoc.Workflows.WorkflowJob do
  @moduledoc """
  WorkflowJob schema - represents a single job/step within a workflow.
  """
  use WraftDoc.Schema

  schema "workflow_jobs" do
    field(:name, :string)
    field(:order, :integer)
    field(:adaptor, :string)
    field(:config, :map, default: %{})
    field(:condition, :map)
    # React Flow X position
    field(:position_x, :float)
    # React Flow Y position
    field(:position_y, :float)

    belongs_to(:workflow, WraftDoc.Workflows.Workflow)
    belongs_to(:credentials, WraftDoc.Workflows.WorkflowCredential)

    has_many(:run_jobs, WraftDoc.Workflows.WorkflowRunJob, foreign_key: :job_id)
    # Edges where this is source
    has_many(:outgoing_edges, WraftDoc.Workflows.WorkflowEdge, foreign_key: :source_job_id)
    # Edges where this is target
    has_many(:incoming_edges, WraftDoc.Workflows.WorkflowEdge, foreign_key: :target_job_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :name,
      :order,
      :adaptor,
      :config,
      :condition,
      :position_x,
      :position_y,
      :workflow_id,
      :credentials_id
    ])
    |> validate_required([:name, :adaptor, :workflow_id])
    |> unique_constraint([:workflow_id, :order], name: :workflow_jobs_unique_order)
  end
end
