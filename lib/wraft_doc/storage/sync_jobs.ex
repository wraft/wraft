defmodule WraftDoc.Storage.SyncJobs do
  @moduledoc """
  Access logs management - handles logging of user actions and
  """

  alias WraftDoc.Repo
  alias WraftDoc.Storage.SyncJob

  def list_storage_sync_jobs do
    Repo.all(SyncJob)
  end

  def get_sync_job!(id), do: Repo.get!(SyncJob, id)

  def create_sync_job(attrs \\ %{}) do
    %SyncJob{}
    |> SyncJob.changeset(attrs)
    |> Repo.insert()
  end

  def update_sync_job(%SyncJob{} = sync_job, attrs) do
    sync_job
    |> SyncJob.changeset(attrs)
    |> Repo.update()
  end

  def delete_sync_job(%SyncJob{} = sync_job) do
    Repo.delete(sync_job)
  end

  def change_sync_job(%SyncJob{} = sync_job, attrs \\ %{}) do
    SyncJob.changeset(sync_job, attrs)
  end
end
