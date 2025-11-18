defmodule WraftDoc.Workflows.WorkflowJobs do
  @moduledoc """
  Context for managing jobs within workflows.
  """
  import Ecto.Query
  alias WraftDoc.Account.User
  alias WraftDoc.Repo
  alias WraftDoc.Workflows.Workflow
  alias WraftDoc.Workflows.WorkflowJob

  @spec add_job(User.t(), Workflow.t(), map) ::
          {:ok, WorkflowJob.t()} | {:error, Ecto.Changeset.t()}
  def add_job(%User{current_org_id: org_id}, %Workflow{id: wf_id, organisation_id: org_id}, attrs) do
    attrs = Map.put(attrs, "workflow_id", wf_id)
    %WorkflowJob{} |> WorkflowJob.changeset(attrs) |> Repo.insert()
  end

  def add_job(_, _, _), do: {:error, :forbidden}

  @spec update_job(User.t(), WorkflowJob.t(), map) :: {:ok, WorkflowJob.t()} | {:error, term}
  def update_job(%User{current_org_id: org_id}, %WorkflowJob{} = job, attrs) do
    with %Workflow{} = w <- Repo.get(Workflow, job.workflow_id),
         true <- w.organisation_id == org_id do
      job |> WorkflowJob.changeset(attrs) |> Repo.update()
    else
      _ -> {:error, :forbidden}
    end
  end

  @spec delete_job(User.t(), WorkflowJob.t()) :: {:ok, WorkflowJob.t()} | {:error, term}
  def delete_job(%User{current_org_id: org_id}, %WorkflowJob{} = job) do
    with %Workflow{} = w <- Repo.get(Workflow, job.workflow_id),
         true <- w.organisation_id == org_id do
      Repo.delete(job)
    else
      _ -> {:error, :forbidden}
    end
  end

  @spec reorder_jobs(User.t(), Workflow.t(), list(%{id: Ecto.UUID.t(), order: integer})) ::
          :ok | {:error, term}
  def reorder_jobs(
        %User{current_org_id: org_id},
        %Workflow{id: wf_id, organisation_id: org_id},
        order_list
      ) do
    result =
      Repo.transaction(fn ->
        Enum.each(order_list, fn %{id: id, order: order} ->
          query =
            from(j in WorkflowJob, where: j.id == ^id and j.workflow_id == ^wf_id)

          Repo.update_all(query, set: [order: order])
        end)
      end)

    case result do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def reorder_jobs(_, _, _), do: {:error, :forbidden}
end
