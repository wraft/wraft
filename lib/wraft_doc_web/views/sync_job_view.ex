defmodule WraftDocWeb.Api.V1.SyncJobView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.SyncJobView

  def render("index.json", %{storage_sync_jobs: sync_jobs}) do
    %{data: render_many(sync_jobs, SyncJobView, "sync_job.json")}
  end

  def render("show.json", %{sync_job: sync_job}) do
    %{data: render_one(sync_job, SyncJobView, "sync_job.json")}
  end

  def render("sync_job.json", %{sync_job: sync_job}) do
    %{
      id: sync_job.id,
      job_type: sync_job.job_type,
      sync_source: sync_job.sync_source,
      status: sync_job.status,
      started_at: sync_job.started_at,
      completed_at: sync_job.completed_at,
      items_processed: sync_job.items_processed,
      items_failed: sync_job.items_failed,
      inserted_at: sync_job.inserted_at,
      updated_at: sync_job.updated_at
    }
  end
end
