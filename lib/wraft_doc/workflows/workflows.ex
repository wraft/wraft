defmodule WraftDoc.Workflows do
  @moduledoc """
  Context for workflow management.
  """
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Repo
  alias WraftDoc.Workflows.Workflow
  alias WraftDoc.Workflows.WorkflowEdge
  alias WraftDoc.Workflows.WorkflowJob
  alias WraftDoc.Workflows.WorkflowTrigger

  @doc """
  Create a workflow scoped to the user's organisation.
  """
  @spec create_workflow(User.t(), map) :: {:ok, Workflow.t()} | {:error, Ecto.Changeset.t()}
  def create_workflow(%User{current_org_id: org_id} = user, attrs) when is_map(attrs) do
    attrs =
      attrs
      |> Map.put("organisation_id", org_id)
      |> Map.put("creator_id", user.id)

    %Workflow{}
    |> Workflow.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  List workflows for current organisation with optional filters and pagination.
  """
  @spec list_workflows(User.t(), map) :: Scrivener.Page.t() | [Workflow.t()]
  def list_workflows(%User{current_org_id: org_id}, params \\ %{}) do
    Workflow
    |> where([w], w.organisation_id == ^org_id)
    |> where(^filter_active(params))
    |> order_by([w], desc: w.inserted_at)
    |> preload([:jobs, :triggers])
    |> Repo.paginate(params)
  end

  defp filter_active(%{"is_active" => true}), do: dynamic([w], w.is_active == true)
  defp filter_active(%{"is_active" => false}), do: dynamic([w], w.is_active == false)
  defp filter_active(_), do: true

  @doc """
  Get a single workflow by id within the user's organisation.
  """
  @spec get_workflow(User.t(), Ecto.UUID.t()) :: Workflow.t() | nil
  def get_workflow(%User{current_org_id: org_id}, workflow_id) do
    Workflow
    |> where([w], w.id == ^workflow_id and w.organisation_id == ^org_id)
    |> preload([[jobs: :credentials], :triggers, :edges])
    |> Repo.one()
  end

  @doc """
  Get a workflow by id for trigger purposes (no user context required).
  Used by webhook triggers and scheduled triggers.
  """
  @spec get_workflow_for_trigger(Ecto.UUID.t()) :: Workflow.t() | nil
  def get_workflow_for_trigger(workflow_id) do
    Workflow
    |> where([w], w.id == ^workflow_id and w.is_active == true)
    |> preload([[jobs: :credentials], :triggers, :edges])
    |> Repo.one()
  end

  @doc """
  Update a workflow (name, description, is_active, config).
  """
  @spec update_workflow(User.t(), Workflow.t(), map) ::
          {:ok, Workflow.t()} | {:error, Ecto.Changeset.t()}
  def update_workflow(
        %User{current_org_id: org_id},
        %Workflow{organisation_id: org_id} = workflow,
        attrs
      ) do
    workflow
    |> Workflow.changeset(attrs)
    |> Repo.update()
  end

  def update_workflow(_, _, _), do: {:error, :forbidden}

  @doc """
  Update workflow structure with jobs and edges.
  This replaces the entire job/edge structure for the workflow.
  """
  @spec update_workflow_structure(User.t(), Workflow.t(), map) ::
          {:ok, Workflow.t()} | {:error, term}
  def update_workflow_structure(
        %User{current_org_id: org_id},
        %Workflow{id: wf_id, organisation_id: org_id} = workflow,
        params
      ) do
    jobs = params["jobs"] || params[:jobs] || []
    edges = params["edges"] || params[:edges] || []
    triggers = params["triggers"] || params[:triggers] || []

    Repo.transaction(fn ->
      job_ids = process_jobs(jobs, wf_id)
      edge_ids = process_edges(edges, wf_id)
      trigger_ids = process_triggers(triggers, wf_id)

      remove_missing_jobs(wf_id, job_ids)
      remove_missing_edges(wf_id, edge_ids)
      remove_missing_triggers(wf_id, trigger_ids)

      {:ok, workflow}
    end)
  end

  def update_workflow_structure(_, _, _), do: {:error, :forbidden}

  @doc """
  Toggle workflow active flag.
  """
  @spec toggle_active(User.t(), Workflow.t()) ::
          {:ok, Workflow.t()} | {:error, Ecto.Changeset.t()}
  def toggle_active(%User{current_org_id: org_id}, %Workflow{organisation_id: org_id} = workflow) do
    update_workflow(%User{current_org_id: org_id}, workflow, %{is_active: !workflow.is_active})
  end

  def toggle_active(_, _), do: {:error, :forbidden}

  @doc """
  Delete a workflow.
  """
  @spec delete_workflow(User.t(), Workflow.t()) ::
          {:ok, Workflow.t()} | {:error, Ecto.Changeset.t()}
  def delete_workflow(
        %User{current_org_id: org_id},
        %Workflow{organisation_id: org_id} = workflow
      ) do
    Repo.delete(workflow)
  end

  def delete_workflow(_, _), do: {:error, :forbidden}

  #
  # Jobs
  #

  @doc """
  Get a job from a workflow by ID.
  """
  @spec get_job(User.t(), Workflow.t(), String.t()) :: WorkflowJob.t() | nil
  def get_job(
        %User{current_org_id: org_id},
        %Workflow{id: wf_id, organisation_id: org_id},
        job_id
      ) do
    query =
      from(j in WorkflowJob,
        where: j.id == ^job_id and j.workflow_id == ^wf_id
      )

    Repo.one(query)
  end

  def get_job(_, _, _), do: nil

  @doc """
  Add a job to a workflow.
  """
  @spec add_job(User.t(), Workflow.t(), map) ::
          {:ok, WorkflowJob.t()} | {:error, Ecto.Changeset.t()}
  def add_job(%User{current_org_id: org_id}, %Workflow{id: wf_id, organisation_id: org_id}, attrs) do
    attrs = Map.put(attrs, "workflow_id", wf_id)

    %WorkflowJob{}
    |> WorkflowJob.changeset(attrs)
    |> Repo.insert()
  end

  def add_job(_, _, _), do: {:error, :forbidden}

  @doc """
  Update a job.
  """
  @spec update_job(User.t(), WorkflowJob.t(), map) ::
          {:ok, WorkflowJob.t()} | {:error, Ecto.Changeset.t()}
  def update_job(%User{current_org_id: org_id}, %WorkflowJob{} = job, attrs) do
    with %Workflow{} = workflow <- Repo.get(Workflow, job.workflow_id),
         true <- workflow.organisation_id == org_id do
      job |> WorkflowJob.changeset(attrs) |> Repo.update()
    else
      _ -> {:error, :forbidden}
    end
  end

  @doc """
  Delete a job.
  """
  @spec delete_job(User.t(), WorkflowJob.t()) ::
          {:ok, WorkflowJob.t()} | {:error, Ecto.Changeset.t()}
  def delete_job(%User{current_org_id: org_id}, %WorkflowJob{} = job) do
    with %Workflow{} = workflow <- Repo.get(Workflow, job.workflow_id),
         true <- workflow.organisation_id == org_id do
      Repo.delete(job)
    else
      _ -> {:error, :forbidden}
    end
  end

  @doc """
  Reorder jobs for a workflow by passing a list of job_id -> order mappings.
  """
  @spec reorder_jobs(User.t(), Workflow.t(), list(%{id: Ecto.UUID.t(), order: integer})) ::
          :ok | {:error, term}
  def reorder_jobs(
        %User{current_org_id: org_id},
        %Workflow{id: wf_id, organisation_id: org_id},
        order_list
      )
      when is_list(order_list) do
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

  # Helper function to validate UUID format
  defp valid_uuid?(id) when is_binary(id) do
    case Ecto.UUID.dump(id) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp valid_uuid?(_), do: false

  defp process_jobs(jobs, wf_id) do
    jobs
    |> Enum.filter(&valid_job?/1)
    |> Enum.map(&upsert_job(&1, wf_id))
  end

  defp valid_job?(job_attrs) do
    job_id = Map.get(job_attrs, "id") || Map.get(job_attrs, :id)
    is_nil(job_id) || valid_uuid?(job_id)
  end

  defp upsert_job(job_attrs, wf_id) do
    job_id = Map.get(job_attrs, "id") || Map.get(job_attrs, :id)

    attributes =
      job_attrs
      |> Map.put("workflow_id", wf_id)
      |> Map.delete("id")

    if valid_uuid?(job_id) do
      case Repo.get(WorkflowJob, job_id) do
        %WorkflowJob{} = job ->
          job
          |> WorkflowJob.changeset(attributes)
          |> Repo.update!()
          |> Map.get(:id)

        _ ->
          create_workflow_job(attributes)
      end
    else
      create_workflow_job(attributes)
    end
  end

  defp create_workflow_job(attributes) do
    %WorkflowJob{}
    |> WorkflowJob.changeset(attributes)
    |> Repo.insert!()
    |> Map.get(:id)
  end

  defp remove_missing_jobs(wf_id, job_ids) do
    existing_job_ids =
      WorkflowJob
      |> where([j], j.workflow_id == ^wf_id)
      |> Repo.all()
      |> Enum.map(& &1.id)

    jobs_to_delete = existing_job_ids -- job_ids

    if Enum.any?(jobs_to_delete) do
      query =
        from(j in WorkflowJob, where: j.id in ^jobs_to_delete and j.workflow_id == ^wf_id)

      Repo.delete_all(query)
    end
  end

  defp process_edges(edges, wf_id) do
    edges
    |> Enum.filter(&valid_edge?/1)
    |> Enum.map(&upsert_edge(&1, wf_id))
  end

  defp valid_edge?(edge_attrs) do
    source_id = Map.get(edge_attrs, "source_job_id") || Map.get(edge_attrs, "source_trigger_id")
    target_id = Map.get(edge_attrs, "target_job_id")
    edge_id = Map.get(edge_attrs, "id") || Map.get(edge_attrs, :id)

    source_valid =
      is_nil(source_id) || valid_uuid?(source_id) || String.starts_with?(source_id, "trigger-")

    target_valid = is_nil(target_id) || valid_uuid?(target_id)
    edge_id_valid = is_nil(edge_id) || valid_uuid?(edge_id)

    source_valid && target_valid && edge_id_valid
  end

  defp upsert_edge(edge_attrs, wf_id) do
    edge_id = Map.get(edge_attrs, "id") || Map.get(edge_attrs, :id)

    attributes =
      edge_attrs
      |> Map.put("workflow_id", wf_id)
      |> Map.delete("id")

    if valid_uuid?(edge_id) do
      case Repo.get(WorkflowEdge, edge_id) do
        %WorkflowEdge{} = edge ->
          edge
          |> WorkflowEdge.changeset(attributes)
          |> Repo.update!()
          |> Map.get(:id)

        _ ->
          create_workflow_edge(attributes)
      end
    else
      create_workflow_edge(attributes)
    end
  end

  defp create_workflow_edge(attributes) do
    %WorkflowEdge{}
    |> WorkflowEdge.changeset(attributes)
    |> Repo.insert!()
    |> Map.get(:id)
  end

  defp remove_missing_edges(wf_id, edge_ids) do
    existing_edge_ids =
      WorkflowEdge
      |> where([e], e.workflow_id == ^wf_id)
      |> Repo.all()
      |> Enum.map(& &1.id)

    edges_to_delete = existing_edge_ids -- edge_ids

    if Enum.any?(edges_to_delete) do
      query =
        from(e in WorkflowEdge, where: e.id in ^edges_to_delete and e.workflow_id == ^wf_id)

      Repo.delete_all(query)
    end
  end

  defp process_triggers(triggers, wf_id) do
    Enum.map(triggers, &upsert_trigger(&1, wf_id))
  end

  defp upsert_trigger(trigger_attrs, wf_id) do
    trigger_id = Map.get(trigger_attrs, "id") || Map.get(trigger_attrs, :id)

    attributes =
      trigger_attrs
      |> Map.put("workflow_id", wf_id)
      |> Map.delete("id")

    if trigger_id && valid_uuid?(trigger_id) do
      case Repo.get(WorkflowTrigger, trigger_id) do
        %WorkflowTrigger{} = trigger ->
          trigger
          |> WorkflowTrigger.changeset(attributes)
          |> Repo.update!()
          |> Map.get(:id)

        _ ->
          create_workflow_trigger(attributes)
      end
    else
      create_workflow_trigger(attributes)
    end
  end

  defp create_workflow_trigger(attributes) do
    %WorkflowTrigger{}
    |> WorkflowTrigger.changeset(attributes)
    |> Repo.insert!()
    |> Map.get(:id)
  end

  defp remove_missing_triggers(wf_id, trigger_ids) do
    existing_trigger_ids =
      WorkflowTrigger
      |> where([t], t.workflow_id == ^wf_id)
      |> Repo.all()
      |> Enum.map(& &1.id)

    triggers_to_delete = existing_trigger_ids -- trigger_ids

    if Enum.any?(triggers_to_delete) do
      query =
        from(t in WorkflowTrigger, where: t.id in ^triggers_to_delete and t.workflow_id == ^wf_id)

      Repo.delete_all(query)
    end
  end

  #
  # Triggers
  #

  @doc """
  Create a trigger for a workflow.
  """
  @spec create_trigger(User.t(), Workflow.t(), map) ::
          {:ok, WorkflowTrigger.t()} | {:error, Ecto.Changeset.t()}
  def create_trigger(
        %User{current_org_id: org_id},
        %Workflow{id: wf_id, organisation_id: org_id},
        attrs
      ) do
    attrs = Map.put(attrs, "workflow_id", wf_id)

    %WorkflowTrigger{}
    |> WorkflowTrigger.changeset(attrs)
    |> Repo.insert()
  end

  def create_trigger(_, _, _), do: {:error, :forbidden}

  @doc """
  Activate/deactivate a trigger.
  """
  @spec set_trigger_active(User.t(), WorkflowTrigger.t(), boolean) ::
          {:ok, WorkflowTrigger.t()} | {:error, term}
  def set_trigger_active(%User{current_org_id: org_id}, %WorkflowTrigger{} = trigger, active?) do
    with %Workflow{} = workflow <- Repo.get(Workflow, trigger.workflow_id),
         true <- workflow.organisation_id == org_id do
      trigger |> WorkflowTrigger.changeset(%{is_active: active?}) |> Repo.update()
    else
      _ -> {:error, :forbidden}
    end
  end
end
