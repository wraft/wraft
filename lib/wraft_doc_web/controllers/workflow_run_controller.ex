defmodule WraftDocWeb.Api.V1.WorkflowRunController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
       [roles: [:creator], create_new: true]
       when action in [:execute, :index, :show]

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Workflows.WorkflowRuns

  def swagger_definitions do
    %{
      WorkflowRun:
        swagger_schema do
          title("Workflow Run")
          description("A workflow execution instance")

          properties do
            id(:string, "The ID of the run", required: true)
            workflow_id(:string, "The workflow ID", required: true)
            state(:string, "Run state (pending, running, completed, failed)")
            input_data(:object, "Input data for the workflow")
            output_data(:object, "Output data from the workflow")
            started_at(:string, "Start time")
            completed_at(:string, "Completion time")
            duration_ms(:integer, "Duration in milliseconds")
            run_jobs(:array, "Job executions")
          end
        end,
      WorkflowExecuteRequest:
        swagger_schema do
          title("Workflow Execute Request")
          description("Request body for executing a workflow")

          properties do
            input_data(:object, "Input data for the workflow", required: true)
          end

          example(%{
            input_data: %{
              age: 30,
              name: "John Doe"
            }
          })
        end
    }
  end

  swagger_path :execute do
    post("/workflows/{workflow_id}/execute")
    summary("Execute a workflow")
    description("Creates and executes a workflow run with provided input data")

    parameters do
      workflow_id(:path, :string, "Workflow ID", required: true)
      body(:body, Schema.ref(:WorkflowExecuteRequest), "Input data", required: true)
    end

    response(200, "Success", Schema.ref(:WorkflowRun))
    response(404, "Workflow not found")
    response(422, "Unprocessable Entity")
    response(401, "Unauthorized")
  end

  def execute(conn, %{"workflow_id" => workflow_id, "input_data" => input_data}) do
    current_user = conn.assigns.current_user

    case WorkflowRuns.create_and_execute_run(current_user, workflow_id, input_data) do
      {:ok, run} ->
        run = WraftDoc.Repo.preload(run, run_jobs: :job, workflow: [:jobs, :edges])
        render(conn, "show.json", run: run)

      {:error, :workflow_not_found} ->
        {:error, :not_found}

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  swagger_path :show do
    get("/workflows/{workflow_id}/runs/{id}")
    summary("Get workflow run details")
    description("Returns a workflow run with all job executions")

    parameters do
      workflow_id(:path, :string, "Workflow ID", required: true)
      id(:path, :string, "Run ID", required: true)
    end

    response(200, "Success", Schema.ref(:WorkflowRun))
    response(404, "Not found")
    response(401, "Unauthorized")
  end

  def show(conn, %{"workflow_id" => _workflow_id, "id" => run_id}) do
    current_user = conn.assigns.current_user

    case WorkflowRuns.get_run(current_user, run_id) do
      nil ->
        {:error, :not_found}

      run ->
        render(conn, "show.json", run: run)
    end
  end

  swagger_path :index do
    get("/workflows/{workflow_id}/runs")
    summary("List workflow runs")
    description("Returns list of all runs for a workflow")

    parameters do
      workflow_id(:path, :string, "Workflow ID", required: true)
      page(:query, :integer, "Page number", required: false)
    end

    response(200, "Success")
    response(401, "Unauthorized")
  end

  def index(conn, %{"workflow_id" => workflow_id} = params) do
    current_user = conn.assigns.current_user

    with %{
           entries: runs,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- WorkflowRuns.list_runs(current_user, workflow_id, params) do
      render(conn, "index.json",
        runs: runs,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
