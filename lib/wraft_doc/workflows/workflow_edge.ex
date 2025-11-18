defmodule WraftDoc.Workflows.WorkflowEdge do
  @moduledoc """
  WorkflowEdge schema - represents a connection in the DAG.
  Follows Lightning's Edge pattern for conditional workflow execution.
  """
  use WraftDoc.Schema
  import Ecto.Changeset

  @condition_types ["on_job_success", "on_job_failure", "always"]

  schema "workflow_edges" do
    belongs_to(:workflow, WraftDoc.Workflows.Workflow)
    belongs_to(:source_job, WraftDoc.Workflows.WorkflowJob)
    belongs_to(:source_trigger, WraftDoc.Workflows.WorkflowTrigger)
    belongs_to(:target_job, WraftDoc.Workflows.WorkflowJob)

    field(:condition_type, :string)
    field(:condition_expression, :string)
    field(:condition_label, :string)
    field(:enabled, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  def changeset(edge, attrs) do
    edge
    |> cast(attrs, [
      :workflow_id,
      :source_job_id,
      :source_trigger_id,
      :target_job_id,
      :condition_type,
      :condition_expression,
      :condition_label,
      :enabled
    ])
    |> validate_required([:workflow_id, :target_job_id, :condition_type])
    |> validate_inclusion(:condition_type, @condition_types)
    |> validate_has_source()
    |> validate_source_exclusive()
    |> validate_source_condition()
    |> validate_different_nodes()
  end

  defp validate_has_source(changeset) do
    source_job = get_field(changeset, :source_job_id)
    source_trigger = get_field(changeset, :source_trigger_id)

    if source_job || source_trigger do
      changeset
    else
      add_error(
        changeset,
        :source_job_id,
        "Either source_job_id or source_trigger_id must be present"
      )
    end
  end

  defp validate_source_exclusive(changeset) do
    source_job = get_field(changeset, :source_job_id)
    source_trigger = get_field(changeset, :source_trigger_id)

    if source_job && source_trigger do
      add_error(
        changeset,
        :source_job_id,
        "source_job_id and source_trigger_id are mutually exclusive"
      )
    else
      changeset
    end
  end

  defp validate_source_condition(changeset) do
    source_trigger = get_field(changeset, :source_trigger_id)
    condition_type = get_field(changeset, :condition_type)

    if source_trigger && condition_type not in ["always"] do
      add_error(
        changeset,
        :condition_type,
        "When source is a trigger, condition_type must be 'always'"
      )
    else
      changeset
    end
  end

  defp validate_different_nodes(changeset) do
    source_job = get_field(changeset, :source_job_id)
    target_job = get_field(changeset, :target_job_id)

    if source_job && source_job == target_job do
      add_error(changeset, :target_job_id, "Target job must be different from source job")
    else
      changeset
    end
  end
end
