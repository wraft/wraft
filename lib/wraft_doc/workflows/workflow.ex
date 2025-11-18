defmodule WraftDoc.Workflows.Workflow do
  @moduledoc """
  Workflow schema - represents a workflow definition.
  """
  use WraftDoc.Schema

  schema "workflows" do
    field(:name, :string)
    field(:description, :string)
    field(:is_active, :boolean, default: true)
    field(:config, :map, default: %{})
    # React Flow positions for visualization
    field(:positions, :map)

    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:creator, WraftDoc.Account.User)
    has_many(:jobs, WraftDoc.Workflows.WorkflowJob, preload_order: [asc: :order])
    has_many(:edges, WraftDoc.Workflows.WorkflowEdge, on_replace: :delete)
    has_many(:triggers, WraftDoc.Workflows.WorkflowTrigger)
    has_many(:runs, WraftDoc.Workflows.WorkflowRun)

    timestamps(type: :utc_datetime)
  end

  def changeset(workflow, attrs) do
    workflow
    |> cast(attrs, [
      :name,
      :description,
      :is_active,
      :config,
      :positions,
      :organisation_id,
      :creator_id
    ])
    |> validate_required([:name, :organisation_id, :creator_id])
    |> unique_constraint([:name, :organisation_id], name: :workflows_name_org_unique)
  end
end
