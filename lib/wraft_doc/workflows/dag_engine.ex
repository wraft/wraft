defmodule WraftDoc.Workflows.DagEngine do
  @moduledoc """
  DAG execution engine for workflows.
  Handles parallel execution, conditional edges, and state tracking.
  """

  alias WraftDoc.Repo
  alias WraftDoc.Workflows.Adaptors.Registry
  alias WraftDoc.Workflows.Workflow
  alias WraftDoc.Workflows.WorkflowCredentials
  alias WraftDoc.Workflows.WorkflowJob
  alias WraftDoc.Workflows.WorkflowRun
  alias WraftDoc.Workflows.WorkflowRunJob
  alias WraftDocWeb.Endpoint

  import Ecto.Query
  require Logger

  @doc """
  Execute a workflow run using DAG engine.
  """
  def execute_run(run_id) do
    with {:ok, run} <- load_run(run_id),
         {:ok, workflow} <- load_workflow(run.workflow_id),
         :ok <- update_run_state(run, "running"),
         {:ok, final_state} <- execute_workflow(workflow, run) do
      finalize_run(run, final_state)
    else
      {:error, reason} = error ->
        Logger.error("[DagEngine] Execution failed for run #{run_id}: #{inspect(reason)}")
        error
    end
  end

  defp load_run(run_id) do
    case Repo.get(WorkflowRun, run_id) do
      nil -> {:error, :run_not_found}
      run -> {:ok, run}
    end
  end

  defp load_workflow(workflow_id) do
    workflow =
      Workflow
      |> where([w], w.id == ^workflow_id)
      |> preload([:edges, :triggers, jobs: :credentials])
      |> Repo.one()

    if workflow, do: {:ok, workflow}, else: {:error, :workflow_not_found}
  end

  defp update_run_state(run, state) do
    run
    |> WorkflowRun.changeset(%{state: state, started_at: DateTime.utc_now()})
    |> Repo.update()

    :ok
  end

  defp execute_workflow(workflow, run) do
    # Build dependency map from edges
    dependency_map = build_dependency_map(workflow.edges)

    # Start with jobs that have no dependencies (entry points)
    entry_jobs = find_entry_jobs(workflow.jobs, dependency_map)

    Logger.info("[DagEngine] Starting execution with #{length(entry_jobs)} entry job(s)")

    # Execute jobs recursively
    execute_jobs_recursive(workflow, run, entry_jobs, dependency_map, %{}, [])
  end

  defp build_dependency_map(edges) do
    # Map: target_job_id -> [{source_job_id, condition_type, condition_label}]
    edges
    |> Enum.filter(&(&1.enabled && &1.source_job_id))
    |> Enum.reduce(%{}, fn edge, acc ->
      dependency = {edge.source_job_id, edge.condition_type, edge.condition_label}
      Map.update(acc, edge.target_job_id, [dependency], fn deps -> [dependency | deps] end)
    end)
  end

  defp find_entry_jobs(jobs, dependency_map) do
    Enum.filter(jobs, fn job ->
      !Map.has_key?(dependency_map, job.id)
    end)
  end

  defp execute_jobs_recursive(_workflow, _run, [], _dependency_map, results, failed_jobs) do
    # All jobs processed
    if Enum.empty?(failed_jobs) do
      {:ok, %{completed: Map.keys(results), failed: []}}
    else
      {:ok, %{completed: Map.keys(results), failed: failed_jobs}}
    end
  end

  defp execute_jobs_recursive(workflow, run, ready_jobs, dependency_map, results, failed_jobs) do
    Logger.info("[DagEngine] Executing #{length(ready_jobs)} ready job(s)")

    # Execute ready jobs in parallel
    task_results =
      ready_jobs
      |> Enum.map(&Task.async(fn -> execute_job(&1, run, results) end))
      # 60 second timeout per job
      |> Enum.map(&Task.await(&1, 60_000))

    # Process results
    {new_results, new_failed} = process_task_results(task_results, results, failed_jobs)

    # Merge results to get all completed jobs so far
    merged_results = Map.merge(results, new_results)

    # Get all completed job IDs (from both old and new results)
    completed_job_ids = merged_results |> Map.keys() |> MapSet.new()

    # Get IDs of jobs we just executed
    executed_job_ids = ready_jobs |> Enum.map(& &1.id) |> MapSet.new()

    # Combine all completed and executed job IDs
    all_completed_ids = MapSet.union(completed_job_ids, executed_job_ids)

    # Find next batch of ready jobs - exclude all jobs that have been completed or executed
    remaining_jobs =
      Enum.reject(workflow.jobs, fn job ->
        MapSet.member?(all_completed_ids, job.id)
      end)

    next_ready = find_next_ready_jobs(remaining_jobs, dependency_map, merged_results)

    if Enum.empty?(next_ready) && !Enum.empty?(remaining_jobs) do
      # No more ready jobs but have remaining jobs - check for deadlock or conditional blocking
      Logger.warning(
        "[DagEngine] Execution stopped with #{length(remaining_jobs)} remaining job(s)"
      )

      {:ok,
       %{
         completed: Map.keys(merged_results),
         failed: new_failed,
         blocked: Enum.map(remaining_jobs, & &1.id)
       }}
    else
      # Continue with next batch - use merged_results to track all completed jobs
      execute_jobs_recursive(
        workflow,
        run,
        next_ready,
        dependency_map,
        merged_results,
        new_failed
      )
    end
  end

  defp execute_job(job, run, previous_results) do
    Logger.info("[DagEngine] Executing job: #{job.name}")

    # Create run_job record
    run_job = create_run_job(job, run)

    # Get adaptor
    case Registry.get_adaptor(job.adaptor) do
      nil ->
        error = "Adaptor '#{job.adaptor}' not found"
        Logger.error("[DagEngine] #{error}")
        update_run_job_failed(run_job, error)
        {:error, job.id, error}

      adaptor ->
        # Merge input data from previous results
        input_data = merge_input_data(run.input_data, previous_results)

        # Load and decrypt credentials for this job
        credentials = load_job_credentials(job)

        # Execute adaptor with credentials
        case adaptor.execute(job.config, input_data, credentials) do
          {:ok, output_data} ->
            Logger.info("[DagEngine] Job #{job.name} completed successfully")
            update_run_job_success(run_job, output_data)
            {:ok, job.id, output_data}

          {:error, reason} ->
            Logger.error("[DagEngine] Job #{job.name} failed: #{inspect(reason)}")
            update_run_job_failed(run_job, reason)
            {:error, job.id, reason}
        end
    end
  end

  defp create_run_job(job, run) do
    run_job =
      %WorkflowRunJob{}
      |> WorkflowRunJob.changeset(%{
        run_id: run.id,
        job_id: job.id,
        state: "running",
        started_at: DateTime.utc_now(),
        input_data: run.input_data
      })
      |> Repo.insert!()

    # Broadcast job started
    Endpoint.broadcast("workflow_run:#{run.id}", "run_job_started", %{
      event: "run_job_started",
      run_job: run_job
    })

    run_job
  end

  defp update_run_job_success(run_job, output_data) do
    run_job =
      run_job
      |> WorkflowRunJob.changeset(%{
        state: "completed",
        completed_at: DateTime.utc_now(),
        output_data: output_data,
        duration_ms: calculate_duration(run_job.started_at)
      })
      |> Repo.update!()

    # Broadcast job completed
    Endpoint.broadcast("workflow_run:#{run_job.run_id}", "run_job_completed", %{
      event: "run_job_completed",
      run_job: run_job
    })

    run_job
  end

  defp update_run_job_failed(run_job, reason) do
    run_job =
      run_job
      |> WorkflowRunJob.changeset(%{
        state: "failed",
        completed_at: DateTime.utc_now(),
        error: %{reason: inspect(reason)},
        duration_ms: calculate_duration(run_job.started_at)
      })
      |> Repo.update!()

    # Broadcast job failed
    Endpoint.broadcast("workflow_run:#{run_job.run_id}", "run_job_failed", %{
      event: "run_job_failed",
      run_job: run_job
    })

    run_job
  end

  defp calculate_duration(started_at) do
    DateTime.diff(DateTime.utc_now(), started_at, :millisecond)
  end

  defp merge_input_data(initial_input, previous_results) do
    # Merge all previous outputs into input
    Enum.reduce(previous_results, initial_input, fn {_job_id, output}, acc ->
      Map.merge(acc, output)
    end)
  end

  defp process_task_results(task_results, results, failed_jobs) do
    Enum.reduce(task_results, {results, failed_jobs}, fn result, {res_acc, fail_acc} ->
      case result do
        {:ok, job_id, output} ->
          {Map.put(res_acc, job_id, output), fail_acc}

        {:error, job_id, _reason} ->
          {res_acc, [job_id | fail_acc]}
      end
    end)
  end

  defp find_next_ready_jobs(remaining_jobs, dependency_map, completed_results) do
    Enum.filter(remaining_jobs, fn job ->
      dependency_map
      |> Map.get(job.id, [])
      |> ready_for_execution?(completed_results)
    end)
  end

  defp ready_for_execution?([], _completed_results), do: true

  defp ready_for_execution?(dependencies, completed_results) do
    Enum.all?(dependencies, &dependency_satisfied?(&1, completed_results))
  end

  defp dependency_satisfied?({source_job_id, condition_type, _label}, completed_results) do
    case Map.fetch(completed_results, source_job_id) do
      {:ok, source_output} -> evaluate_condition(condition_type, source_output)
      :error -> false
    end
  end

  defp evaluate_condition("always", _output), do: true

  defp evaluate_condition("on_job_success", output) do
    # Consider job successful if it has result: true or no error
    !Map.has_key?(output, :error) && Map.get(output, :result, true)
  end

  defp evaluate_condition("on_job_failure", output) do
    # Consider job failed if it has result: false or error
    Map.has_key?(output, :error) || Map.get(output, :result, false) == false
  end

  defp evaluate_condition(_type, _output), do: false

  # defp find_job_by_id(jobs, job_id) do
  #   Enum.find(jobs, fn job -> job.id == job_id end)
  # end

  defp load_job_credentials(%WorkflowJob{credentials_id: nil}), do: nil

  defp load_job_credentials(%WorkflowJob{credentials_id: credential_id}) do
    case Repo.get(WraftDoc.Workflows.WorkflowCredential, credential_id) do
      nil -> nil
      credential -> WorkflowCredentials.decrypt_credentials(credential)
    end
  end

  defp finalize_run(run, %{completed: completed, failed: failed} = _final_state) do
    state = if Enum.empty?(failed), do: "completed", else: "failed"

    case run
         |> WorkflowRun.changeset(%{
           state: state,
           completed_at: DateTime.utc_now(),
           duration_ms: calculate_duration(run.started_at || run.inserted_at)
         })
         |> Repo.update() do
      {:ok, updated_run} ->
        # Broadcast run completed
        Endpoint.broadcast("workflow_run:#{updated_run.id}", "run_completed", %{
          event: "run_completed",
          run: updated_run
        })

        Logger.info(
          "[DagEngine] Workflow run #{updated_run.id} finalized: #{state} (#{length(completed)} completed, #{length(failed)} failed)"
        )

        {:ok, updated_run}

      {:error, changeset} ->
        Logger.error("[DagEngine] Failed to finalize run #{run.id}: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end
end
