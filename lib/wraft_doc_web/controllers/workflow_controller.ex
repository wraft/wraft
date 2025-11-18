defmodule WraftDocWeb.Api.V1.WorkflowController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
       [roles: [:creator], create_new: true]
       when action in [:index, :show]

  action_fallback(WraftDocWeb.FallbackController)

  import Ecto.Query

  alias WraftDoc.Repo
  alias WraftDoc.Workflows
  alias WraftDoc.Workflows.Workflow
  alias WraftDoc.Workflows.WorkflowEdge
  alias WraftDoc.Workflows.WorkflowJob

  def swagger_definitions do
    %{
      Workflow:
        swagger_schema do
          title("Workflow")
          description("A workflow with DAG structure")

          properties do
            id(:string, "The ID of the workflow", required: true)
            name(:string, "Workflow name", required: true)
            description(:string, "Workflow description")
            is_active(:boolean, "Whether workflow is active")
            jobs(:array, "Workflow jobs")
            edges(:array, "Workflow edges")
          end
        end,
      WorkflowRequest:
        swagger_schema do
          title("Workflow Request")
          description("Request body for workflow operations")

          properties do
            workflow(Schema.ref(:WorkflowData))
          end
        end,
      WorkflowData:
        swagger_schema do
          title("Workflow Data")

          properties do
            name(:string, "Workflow name", required: true)
            description(:string, "Workflow description")
          end
        end
    }
  end

  swagger_path :index do
    get("/workflows")
    summary("List workflows")
    description("Returns list of all workflows for the current organization")

    parameters do
      page(:query, :integer, "Page number", required: false)
    end

    response(200, "Success")
    response(422, "Unprocessable Entity")
    response(401, "Unauthorized")
  end

  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: workflows,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Workflows.list_workflows(current_user, params) do
      render(conn, "index.json",
        workflows: workflows,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  swagger_path :show do
    get("/workflows/{id}")
    summary("Get workflow details")
    description("Returns a workflow with jobs and edges")

    parameters do
      id(:path, :string, "Workflow ID", required: true)
    end

    response(200, "Success")
    response(404, "Not found")
    response(401, "Unauthorized")
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    case Workflows.get_workflow(current_user, id) do
      nil ->
        {:error, :not_found}

      workflow ->
        render(conn, "show.json", workflow: workflow)
    end
  end

  swagger_path :create do
    post("/workflows")
    summary("Create a new workflow")
    description("Creates a new workflow with optional jobs and edges")

    parameters do
      body(:body, Schema.ref(:WorkflowRequest), "Workflow data", required: true)
    end

    response(201, "Created")
    response(422, "Unprocessable Entity")
    response(401, "Unauthorized")
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    case Workflows.create_workflow(current_user, params) do
      {:ok, workflow} ->
        updated_workflow = maybe_update_workflow_structure(current_user, workflow, params)

        conn
        |> put_status(:created)
        |> render("show.json", workflow: updated_workflow)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(WraftDocWeb.ErrorView)
        |> render("error.json", changeset: changeset)
    end
  end

  defp maybe_update_workflow_structure(current_user, workflow, params) do
    if params["jobs"] || params["edges"] do
      update_structure_with_jobs_edges(current_user, workflow, params)
    else
      Workflows.get_workflow(current_user, workflow.id) || workflow
    end
  end

  defp update_structure_with_jobs_edges(current_user, workflow, params) do
    case Workflows.update_workflow_structure(current_user, workflow, %{
           jobs: params["jobs"] || [],
           edges: params["edges"] || []
         }) do
      {:ok, _updated} -> Workflows.get_workflow(current_user, workflow.id) || workflow
      {:error, _} -> workflow
    end
  end

  swagger_path :update do
    patch("/workflows/{id}")
    summary("Update workflow with jobs and edges")
    description("Updates a workflow, including its jobs and edges structure")

    parameters do
      id(:path, :string, "Workflow ID", required: true)
    end

    response(200, "Success")
    response(422, "Unprocessable Entity")
    response(401, "Unauthorized")
    response(404, "Not found")
  end

  def update(conn, %{"id" => id, "jobs" => jobs, "edges" => edges} = params) do
    current_user = conn.assigns.current_user

    case Workflows.get_workflow(current_user, id) do
      nil ->
        {:error, :not_found}

      workflow ->
        update_params = %{
          jobs: jobs,
          edges: edges,
          triggers: params["triggers"] || []
        }

        case Workflows.update_workflow_structure(current_user, workflow, update_params) do
          {:ok, _updated_workflow} ->
            updated_workflow = Workflows.get_workflow(current_user, id)
            render(conn, "show.json", workflow: updated_workflow)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(WraftDocWeb.ErrorView)
            |> render("error.json", changeset: changeset)
        end
    end
  end

  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    case Workflows.get_workflow(current_user, id) do
      nil ->
        {:error, :not_found}

      workflow ->
        case Workflows.update_workflow(current_user, workflow, params) do
          {:ok, updated_workflow} ->
            render(conn, "show.json", workflow: updated_workflow)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(WraftDocWeb.ErrorView)
            |> render("error.json", changeset: changeset)
        end
    end
  end

  swagger_path :delete_job do
    delete("/workflows/:workflow_id/jobs/:job_id")
    summary("Delete a workflow job")
    description("Deletes a job from a workflow")

    parameters do
      workflow_id(:path, :string, "Workflow ID", required: true)
      job_id(:path, :string, "Job ID", required: true)
    end

    response(200, "Success")
    response(404, "Not found")
    response(401, "Unauthorized")
    response(403, "Forbidden")
  end

  def delete_job(conn, %{"workflow_id" => workflow_id, "job_id" => job_id}) do
    current_user = conn.assigns.current_user

    with %Workflow{} = workflow <- Workflows.get_workflow(current_user, workflow_id),
         %WorkflowJob{} = job <- Workflows.get_job(current_user, workflow, job_id) do
      case Workflows.delete_job(current_user, job) do
        {:ok, _deleted_job} ->
          # Also delete associated edges
          # Delete edges where this job is source or target
          Repo.delete_all(
            from(e in WorkflowEdge,
              where: e.source_job_id == ^job_id or e.target_job_id == ^job_id
            )
          )

          json(conn, %{message: "Job deleted successfully"})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(WraftDocWeb.ErrorView)
          |> render("error.json", changeset: changeset)
      end
    else
      _ ->
        {:error, :not_found}
    end
  end
end
