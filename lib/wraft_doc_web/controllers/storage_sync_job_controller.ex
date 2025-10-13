defmodule WraftDocWeb.Api.V1.StorageSyncJobController do
  use WraftDocWeb, :controller
  alias WraftDoc.Storage.SyncJob
  alias WraftDoc.Storage.SyncJobs, as: Storage

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  action_fallback(WraftDocWeb.FallbackController)

  def index(conn, _params) do
    storage_sync_jobs = Storage.list_storage_sync_jobs()
    render(conn, :index, storage_sync_jobs: storage_sync_jobs)
  end

  def create(conn, %{"sync_job" => sync_job_params}) do
    with {:ok, %SyncJob{} = sync_job} <- Storage.create_sync_job(sync_job_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/storage_sync_jobs/#{sync_job}")
      |> render(:show, sync_job: sync_job)
    end
  end

  def show(conn, %{"id" => id}) do
    sync_job = Storage.get_sync_job!(id)
    render(conn, :show, sync_job: sync_job)
  end

  def update(conn, %{"id" => id, "sync_job" => sync_job_params}) do
    sync_job = Storage.get_sync_job!(id)

    with {:ok, %SyncJob{} = sync_job} <- Storage.update_sync_job(sync_job, sync_job_params) do
      render(conn, :show, sync_job: sync_job)
    end
  end

  def delete(conn, %{"id" => id}) do
    sync_job = Storage.get_sync_job!(id)

    with {:ok, %SyncJob{}} <- Storage.delete_sync_job(sync_job) do
      send_resp(conn, :no_content, "")
    end
  end
end
