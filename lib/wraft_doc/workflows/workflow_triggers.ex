defmodule WraftDoc.Workflows.WorkflowTriggers do
  @moduledoc """
  Context for managing workflow triggers.
  """
  alias WraftDoc.Account.User
  alias WraftDoc.Repo
  alias WraftDoc.Workflows.Workflow
  alias WraftDoc.Workflows.WorkflowTrigger

  @spec create_trigger(User.t(), Workflow.t(), map) ::
          {:ok, WorkflowTrigger.t()} | {:error, Ecto.Changeset.t()}
  def create_trigger(
        %User{current_org_id: org_id},
        %Workflow{id: wf_id, organisation_id: org_id},
        attrs
      ) do
    attrs = Map.put(attrs, "workflow_id", wf_id)
    %WorkflowTrigger{} |> WorkflowTrigger.changeset(attrs) |> Repo.insert()
  end

  def create_trigger(_, _, _), do: {:error, :forbidden}

  @spec activate_trigger(User.t(), WorkflowTrigger.t()) ::
          {:ok, WorkflowTrigger.t()} | {:error, term}
  def activate_trigger(%User{current_org_id: org_id}, %WorkflowTrigger{} = trigger),
    do: set_trigger_active(org_id, trigger, true)

  @spec deactivate_trigger(User.t(), WorkflowTrigger.t()) ::
          {:ok, WorkflowTrigger.t()} | {:error, term}
  def deactivate_trigger(%User{current_org_id: org_id}, %WorkflowTrigger{} = trigger),
    do: set_trigger_active(org_id, trigger, false)

  defp set_trigger_active(org_id, %WorkflowTrigger{} = trigger, active?) do
    case Repo.get(Workflow, trigger.workflow_id) do
      %Workflow{organisation_id: ^org_id} ->
        trigger |> WorkflowTrigger.changeset(%{is_active: active?}) |> Repo.update()

      _ ->
        {:error, :forbidden}
    end
  end
end
