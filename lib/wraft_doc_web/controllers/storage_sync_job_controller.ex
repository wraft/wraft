defmodule WraftDocWeb.Api.V1.StorageSyncJobController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDoc.Storages.SyncJob
  alias WraftDoc.Storages.SyncJobs, as: Storages
  alias WraftDocWeb.Schemas

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Storage Sync Jobs"])

  @doc """
  List all storage sync jobs
  """
  operation(:index,
    summary: "List all storage sync jobs",
    description: "API to list all storage synchronization jobs",
    responses: [
      ok: {"Ok", "application/json", Schemas.StorageSyncJob.SyncJobsList},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  def index(conn, _params) do
    storage_sync_jobs = Storages.list_storage_sync_jobs()
    render(conn, :index, storage_sync_jobs: storage_sync_jobs)
  end

  @doc """
  Create a new storage sync job
  """
  operation(:create,
    summary: "Create a storage sync job",
    description: "API to create a new storage synchronization job",
    request_body:
      {"Sync job to create", "application/json", Schemas.StorageSyncJob.SyncJobRequest},
    responses: [
      created: {"Created", "application/json", Schemas.StorageSyncJob.SyncJobResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  def create(conn, %{"sync_job" => sync_job_params}) do
    with {:ok, %SyncJob{} = sync_job} <- Storages.create_sync_job(sync_job_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/storage_sync_jobs/#{sync_job}")
      |> render(:show, sync_job: sync_job)
    end
  end

  @doc """
  Show a storage sync job
  """
  operation(:show,
    summary: "Show a storage sync job",
    description: "API to show details of a specific storage sync job",
    parameters: [
      id: [in: :path, type: :string, description: "Sync job ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.StorageSyncJob.SyncJobResponse},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    sync_job = Storages.get_sync_job!(id)
    render(conn, :show, sync_job: sync_job)
  end

  @doc """
  Update a storage sync job
  """
  operation(:update,
    summary: "Update a storage sync job",
    description: "API to update an existing storage sync job",
    parameters: [
      id: [in: :path, type: :string, description: "Sync job ID", required: true]
    ],
    request_body: {"Sync job updates", "application/json", Schemas.StorageSyncJob.SyncJobRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.StorageSyncJob.SyncJobResponse},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  def update(conn, %{"id" => id, "sync_job" => sync_job_params}) do
    sync_job = Storages.get_sync_job!(id)

    with {:ok, %SyncJob{} = sync_job} <- Storages.update_sync_job(sync_job, sync_job_params) do
      render(conn, :show, sync_job: sync_job)
    end
  end

  @doc """
  Delete a storage sync job
  """
  operation(:delete,
    summary: "Delete a storage sync job",
    description: "API to delete a storage sync job",
    parameters: [
      id: [in: :path, type: :string, description: "Sync job ID", required: true]
    ],
    responses: [
      no_content: {"No Content", "application/json", nil},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  def delete(conn, %{"id" => id}) do
    sync_job = Storages.get_sync_job!(id)

    with {:ok, %SyncJob{}} <- Storages.delete_sync_job(sync_job) do
      send_resp(conn, :no_content, "")
    end
  end
end
