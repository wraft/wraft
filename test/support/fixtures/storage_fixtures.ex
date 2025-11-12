defmodule WraftDoc.StorageFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `WraftDoc.Storage` context.
  """

  @doc """
  Generate a repository.
  """
  def repository_fixture(attrs \\ %{}) do
    {:ok, repository} =
      attrs
      |> Enum.into(%{
        current_storage_used: 42,
        description: "some description",
        item_count: 42,
        name: "some name",
        status: "some status",
        storage_limit: 42
      })
      |> WraftDoc.Storages.create_repository()

    repository
  end

  @doc """
  Generate a storage_asset.
  """
  def storage_asset_fixture(attrs \\ %{}) do
    {:ok, storage_asset} =
      attrs
      |> Enum.into(%{
        checksum_sha256: "some checksum_sha256",
        compression_type: "some compression_type",
        encryption_key_id: "some encryption_key_id",
        file_size: 42,
        mime_type: "some mime_type",
        preview_path: "some preview_path",
        processing_status: "some processing_status",
        storage_backend: "some storage_backend",
        storage_key: "some storage_key",
        thumbnail_path: "some thumbnail_path",
        upload_completed_at: ~U[2025-06-07 20:42:00Z]
      })
      |> WraftDoc.Storages.create_storage_asset()

    storage_asset
  end

  @doc """
  Generate a storage_item.
  """
  def storage_item_fixture(attrs \\ %{}) do
    {:ok, storage_item} =
      attrs
      |> Enum.into(%{
        checksum_sha256: "some checksum_sha256",
        classification_level: "some classification_level",
        content_extracted: true,
        deleted_at: ~U[2025-06-07 20:46:00Z],
        depth_level: 42,
        display_name: "some display_name",
        download_count: 42,
        external_id: "some external_id",
        external_metadata: %{},
        file_extension: "some file_extension",
        is_current_version: true,
        is_deleted: true,
        item_type: "some item_type",
        last_accessed_at: ~U[2025-06-07 20:46:00Z],
        last_synced_at: ~U[2025-06-07 20:46:00Z],
        materialized_path: "some materialized_path",
        metadata: %{},
        mime_type: "some mime_type",
        name: "some name",
        path: "some path",
        path_hash: "some path_hash",
        size: 42,
        sync_source: "some sync_source",
        thumbnail_generated: true,
        version_number: "some version_number"
      })
      |> WraftDoc.Storages.create_storage_item()

    storage_item
  end

  @doc """
  Generate a access_log.
  """
  def access_log_fixture(attrs \\ %{}) do
    {:ok, access_log} =
      attrs
      |> Enum.into(%{
        action: "some action",
        ip_address: "some ip_address",
        metadata: %{},
        session_id: "some session_id",
        success: true,
        user_agent: "some user_agent"
      })
      |> WraftDoc.Storages.create_access_log()

    access_log
  end

  @doc """
  Generate a sync_job.
  """
  def sync_job_fixture(attrs \\ %{}) do
    {:ok, sync_job} =
      attrs
      |> Enum.into(%{
        completed_at: ~U[2025-06-07 21:00:00Z],
        error_details: %{},
        items_failed: 42,
        items_processed: 42,
        job_type: "some job_type",
        started_at: ~U[2025-06-07 21:00:00Z],
        status: "some status",
        sync_source: "some sync_source"
      })
      |> WraftDoc.Storages.create_sync_job()

    sync_job
  end
end
