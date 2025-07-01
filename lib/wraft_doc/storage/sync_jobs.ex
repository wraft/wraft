defmodule WraftDoc.Storage.SyncJobs do
  @moduledoc """
  Context module for managing storage synchronization jobs.

  This module provides functions to create, read, update, and delete
  sync jobs that handle synchronization between different storage systems.
  """

  alias WraftDoc.Repo
  alias WraftDoc.Storage.SyncJob

  @type sync_job_attrs :: map()
  @type sync_job_result :: {:ok, SyncJob.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Returns the list of all storage sync jobs.

  ## Examples

      iex> list_storage_sync_jobs()
      [%SyncJob{}, ...]

  """
  @spec list_storage_sync_jobs() :: [SyncJob.t()]
  def list_storage_sync_jobs do
    Repo.all(SyncJob)
  end

  @doc """
  Gets a single sync job by ID.

  Raises `Ecto.NoResultsError` if the sync job does not exist.

  ## Examples

      iex> get_sync_job!(123)
      %SyncJob{}

      iex> get_sync_job!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_sync_job!(integer()) :: SyncJob.t()
  def get_sync_job!(id), do: Repo.get!(SyncJob, id)

  @doc """
  Creates a sync job with the given attributes.

  ## Examples

      iex> create_sync_job(%{field: value})
      {:ok, %SyncJob{}}

      iex> create_sync_job(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_sync_job(sync_job_attrs()) :: sync_job_result()
  def create_sync_job(attrs \\ %{}) do
    %SyncJob{}
    |> SyncJob.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a sync job with the given attributes.

  ## Examples

      iex> update_sync_job(sync_job, %{field: new_value})
      {:ok, %SyncJob{}}

      iex> update_sync_job(sync_job, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_sync_job(SyncJob.t(), sync_job_attrs()) :: sync_job_result()
  def update_sync_job(%SyncJob{} = sync_job, attrs) do
    sync_job
    |> SyncJob.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a sync job.

  ## Examples

      iex> delete_sync_job(sync_job)
      {:ok, %SyncJob{}}

      iex> delete_sync_job(sync_job)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_sync_job(SyncJob.t()) :: sync_job_result()
  def delete_sync_job(%SyncJob{} = sync_job) do
    Repo.delete(sync_job)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking sync job changes.

  ## Examples

      iex> change_sync_job(sync_job)
      %Ecto.Changeset{data: %SyncJob{}}

  """
  @spec change_sync_job(SyncJob.t(), sync_job_attrs()) :: Ecto.Changeset.t()
  def change_sync_job(%SyncJob{} = sync_job, attrs \\ %{}) do
    SyncJob.changeset(sync_job, attrs)
  end
end
