defmodule WraftDoc.StorageTest do
  use WraftDoc.DataCase

  alias WraftDoc.Storages

  describe "repositories" do
    alias WraftDoc.Storage.Repository

    import WraftDoc.StorageFixtures

    @invalid_attrs %{
      name: nil,
      status: nil,
      description: nil,
      storage_limit: nil,
      current_storage_used: nil,
      item_count: nil
    }

    test "list_repositories/0 returns all repositories" do
      repository = repository_fixture()
      assert Storage.list_repositories() == [repository]
    end

    test "get_repository!/1 returns the repository with given id" do
      repository = repository_fixture()
      assert Storage.get_repository!(repository.id) == repository
    end

    test "create_repository/1 with valid data creates a repository" do
      valid_attrs = %{
        name: "some name",
        status: "some status",
        description: "some description",
        storage_limit: 42,
        current_storage_used: 42,
        item_count: 42
      }

      assert {:ok, %Repository{} = repository} = Storage.create_repository(valid_attrs)
      assert repository.name == "some name"
      assert repository.status == "some status"
      assert repository.description == "some description"
      assert repository.storage_limit == 42
      assert repository.current_storage_used == 42
      assert repository.item_count == 42
    end

    test "create_repository/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Storage.create_repository(@invalid_attrs)
    end

    test "update_repository/2 with valid data updates the repository" do
      repository = repository_fixture()

      update_attrs = %{
        name: "some updated name",
        status: "some updated status",
        description: "some updated description",
        storage_limit: 43,
        current_storage_used: 43,
        item_count: 43
      }

      assert {:ok, %Repository{} = repository} =
               Storage.update_repository(repository, update_attrs)

      assert repository.name == "some updated name"
      assert repository.status == "some updated status"
      assert repository.description == "some updated description"
      assert repository.storage_limit == 43
      assert repository.current_storage_used == 43
      assert repository.item_count == 43
    end

    test "update_repository/2 with invalid data returns error changeset" do
      repository = repository_fixture()
      assert {:error, %Ecto.Changeset{}} = Storage.update_repository(repository, @invalid_attrs)
      assert repository == Storage.get_repository!(repository.id)
    end

    test "delete_repository/1 deletes the repository" do
      repository = repository_fixture()
      assert {:ok, %Repository{}} = Storage.delete_repository(repository)
      assert_raise Ecto.NoResultsError, fn -> Storage.get_repository!(repository.id) end
    end

    test "change_repository/1 returns a repository changeset" do
      repository = repository_fixture()
      assert %Ecto.Changeset{} = Storage.change_repository(repository)
    end
  end

  describe "storage_assets" do
    alias WraftDoc.Storages.StorageAsset

    import WraftDoc.StoragesFixtures

    @invalid_attrs %{
      storage_key: nil,
      storage_backend: nil,
      file_size: nil,
      checksum_sha256: nil,
      mime_type: nil,
      encryption_key_id: nil,
      compression_type: nil,
      thumbnail_path: nil,
      preview_path: nil,
      processing_status: nil,
      upload_completed_at: nil
    }

    test "list_storage_assets/0 returns all storage_assets" do
      storage_asset = storage_asset_fixture()
      assert Storage.list_storage_assets() == [storage_asset]
    end

    test "get_storage_asset!/1 returns the storage_asset with given id" do
      storage_asset = storage_asset_fixture()
      assert Storage.get_storage_asset!(storage_asset.id) == storage_asset
    end

    test "create_storage_asset/1 with valid data creates a storage_asset" do
      valid_attrs = %{
        storage_key: "some storage_key",
        storage_backend: "some storage_backend",
        file_size: 42,
        checksum_sha256: "some checksum_sha256",
        mime_type: "some mime_type",
        encryption_key_id: "some encryption_key_id",
        compression_type: "some compression_type",
        thumbnail_path: "some thumbnail_path",
        preview_path: "some preview_path",
        processing_status: "some processing_status",
        upload_completed_at: ~U[2025-06-07 20:42:00Z]
      }

      assert {:ok, %StorageAsset{} = storage_asset} = Storage.create_storage_asset(valid_attrs)
      assert storage_asset.storage_key == "some storage_key"
      assert storage_asset.storage_backend == "some storage_backend"
      assert storage_asset.file_size == 42
      assert storage_asset.checksum_sha256 == "some checksum_sha256"
      assert storage_asset.mime_type == "some mime_type"
      assert storage_asset.encryption_key_id == "some encryption_key_id"
      assert storage_asset.compression_type == "some compression_type"
      assert storage_asset.thumbnail_path == "some thumbnail_path"
      assert storage_asset.preview_path == "some preview_path"
      assert storage_asset.processing_status == "some processing_status"
      assert storage_asset.upload_completed_at == ~U[2025-06-07 20:42:00Z]
    end

    test "create_storage_asset/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Storage.create_storage_asset(@invalid_attrs)
    end

    test "update_storage_asset/2 with valid data updates the storage_asset" do
      storage_asset = storage_asset_fixture()

      update_attrs = %{
        storage_key: "some updated storage_key",
        storage_backend: "some updated storage_backend",
        file_size: 43,
        checksum_sha256: "some updated checksum_sha256",
        mime_type: "some updated mime_type",
        encryption_key_id: "some updated encryption_key_id",
        compression_type: "some updated compression_type",
        thumbnail_path: "some updated thumbnail_path",
        preview_path: "some updated preview_path",
        processing_status: "some updated processing_status",
        upload_completed_at: ~U[2025-06-08 20:42:00Z]
      }

      assert {:ok, %StorageAsset{} = storage_asset} =
               Storage.update_storage_asset(storage_asset, update_attrs)

      assert storage_asset.storage_key == "some updated storage_key"
      assert storage_asset.storage_backend == "some updated storage_backend"
      assert storage_asset.file_size == 43
      assert storage_asset.checksum_sha256 == "some updated checksum_sha256"
      assert storage_asset.mime_type == "some updated mime_type"
      assert storage_asset.encryption_key_id == "some updated encryption_key_id"
      assert storage_asset.compression_type == "some updated compression_type"
      assert storage_asset.thumbnail_path == "some updated thumbnail_path"
      assert storage_asset.preview_path == "some updated preview_path"
      assert storage_asset.processing_status == "some updated processing_status"
      assert storage_asset.upload_completed_at == ~U[2025-06-08 20:42:00Z]
    end

    test "update_storage_asset/2 with invalid data returns error changeset" do
      storage_asset = storage_asset_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Storage.update_storage_asset(storage_asset, @invalid_attrs)

      assert storage_asset == Storage.get_storage_asset!(storage_asset.id)
    end

    test "delete_storage_asset/1 deletes the storage_asset" do
      storage_asset = storage_asset_fixture()
      assert {:ok, %StorageAsset{}} = Storage.delete_storage_asset(storage_asset)
      assert_raise Ecto.NoResultsError, fn -> Storage.get_storage_asset!(storage_asset.id) end
    end

    test "change_storage_asset/1 returns a storage_asset changeset" do
      storage_asset = storage_asset_fixture()
      assert %Ecto.Changeset{} = Storage.change_storage_asset(storage_asset)
    end
  end

  describe "storage_items" do
    alias WraftDoc.Storages.StorageItem

    import WraftDoc.StorageFixtures

    @invalid_attrs %{
      name: nil,
      size: nil,
      path: nil,
      metadata: nil,
      display_name: nil,
      item_type: nil,
      path_hash: nil,
      depth_level: nil,
      materialized_path: nil,
      mime_type: nil,
      file_extension: nil,
      checksum_sha256: nil,
      version_number: nil,
      is_current_version: nil,
      classification_level: nil,
      is_deleted: nil,
      deleted_at: nil,
      sync_source: nil,
      external_id: nil,
      external_metadata: nil,
      last_synced_at: nil,
      content_extracted: nil,
      thumbnail_generated: nil,
      download_count: nil,
      last_accessed_at: nil
    }

    test "list_storage_items/0 returns all storage_items" do
      storage_item = storage_item_fixture()
      assert Storage.list_storage_items() == [storage_item]
    end

    test "get_storage_item!/1 returns the storage_item with given id" do
      storage_item = storage_item_fixture()
      assert Storage.get_storage_item!(storage_item.id) == storage_item
    end

    test "create_storage_item/1 with valid data creates a storage_item" do
      valid_attrs = %{
        name: "some name",
        size: 42,
        path: "some path",
        metadata: %{},
        display_name: "some display_name",
        item_type: "some item_type",
        path_hash: "some path_hash",
        depth_level: 42,
        materialized_path: "some materialized_path",
        mime_type: "some mime_type",
        file_extension: "some file_extension",
        checksum_sha256: "some checksum_sha256",
        version_number: "some version_number",
        is_current_version: true,
        classification_level: "some classification_level",
        is_deleted: true,
        deleted_at: ~U[2025-06-07 20:46:00Z],
        sync_source: "some sync_source",
        external_id: "some external_id",
        external_metadata: %{},
        last_synced_at: ~U[2025-06-07 20:46:00Z],
        content_extracted: true,
        thumbnail_generated: true,
        download_count: 42,
        last_accessed_at: ~U[2025-06-07 20:46:00Z]
      }

      assert {:ok, %StorageItem{} = storage_item} = Storage.create_storage_item(valid_attrs)
      assert storage_item.name == "some name"
      assert storage_item.size == 42
      assert storage_item.path == "some path"
      assert storage_item.metadata == %{}
      assert storage_item.display_name == "some display_name"
      assert storage_item.item_type == "some item_type"
      assert storage_item.path_hash == "some path_hash"
      assert storage_item.depth_level == 42
      assert storage_item.materialized_path == "some materialized_path"
      assert storage_item.mime_type == "some mime_type"
      assert storage_item.file_extension == "some file_extension"
      assert storage_item.checksum_sha256 == "some checksum_sha256"
      assert storage_item.version_number == "some version_number"
      assert storage_item.is_current_version == true
      assert storage_item.classification_level == "some classification_level"
      assert storage_item.is_deleted == true
      assert storage_item.deleted_at == ~U[2025-06-07 20:46:00Z]
      assert storage_item.sync_source == "some sync_source"
      assert storage_item.external_id == "some external_id"
      assert storage_item.external_metadata == %{}
      assert storage_item.last_synced_at == ~U[2025-06-07 20:46:00Z]
      assert storage_item.content_extracted == true
      assert storage_item.thumbnail_generated == true
      assert storage_item.download_count == 42
      assert storage_item.last_accessed_at == ~U[2025-06-07 20:46:00Z]
    end

    test "create_storage_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Storage.create_storage_item(@invalid_attrs)
    end

    test "update_storage_item/2 with valid data updates the storage_item" do
      storage_item = storage_item_fixture()

      update_attrs = %{
        name: "some updated name",
        size: 43,
        path: "some updated path",
        metadata: %{},
        display_name: "some updated display_name",
        item_type: "some updated item_type",
        path_hash: "some updated path_hash",
        depth_level: 43,
        materialized_path: "some updated materialized_path",
        mime_type: "some updated mime_type",
        file_extension: "some updated file_extension",
        checksum_sha256: "some updated checksum_sha256",
        version_number: "some updated version_number",
        is_current_version: false,
        classification_level: "some updated classification_level",
        is_deleted: false,
        deleted_at: ~U[2025-06-08 20:46:00Z],
        sync_source: "some updated sync_source",
        external_id: "some updated external_id",
        external_metadata: %{},
        last_synced_at: ~U[2025-06-08 20:46:00Z],
        content_extracted: false,
        thumbnail_generated: false,
        download_count: 43,
        last_accessed_at: ~U[2025-06-08 20:46:00Z]
      }

      assert {:ok, %StorageItem{} = storage_item} =
               Storage.update_storage_item(storage_item, update_attrs)

      assert storage_item.name == "some updated name"
      assert storage_item.size == 43
      assert storage_item.path == "some updated path"
      assert storage_item.metadata == %{}
      assert storage_item.display_name == "some updated display_name"
      assert storage_item.item_type == "some updated item_type"
      assert storage_item.path_hash == "some updated path_hash"
      assert storage_item.depth_level == 43
      assert storage_item.materialized_path == "some updated materialized_path"
      assert storage_item.mime_type == "some updated mime_type"
      assert storage_item.file_extension == "some updated file_extension"
      assert storage_item.checksum_sha256 == "some updated checksum_sha256"
      assert storage_item.version_number == "some updated version_number"
      assert storage_item.is_current_version == false
      assert storage_item.classification_level == "some updated classification_level"
      assert storage_item.is_deleted == false
      assert storage_item.deleted_at == ~U[2025-06-08 20:46:00Z]
      assert storage_item.sync_source == "some updated sync_source"
      assert storage_item.external_id == "some updated external_id"
      assert storage_item.external_metadata == %{}
      assert storage_item.last_synced_at == ~U[2025-06-08 20:46:00Z]
      assert storage_item.content_extracted == false
      assert storage_item.thumbnail_generated == false
      assert storage_item.download_count == 43
      assert storage_item.last_accessed_at == ~U[2025-06-08 20:46:00Z]
    end

    test "update_storage_item/2 with invalid data returns error changeset" do
      storage_item = storage_item_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Storage.update_storage_item(storage_item, @invalid_attrs)

      assert storage_item == Storage.get_storage_item!(storage_item.id)
    end

    test "delete_storage_item/1 deletes the storage_item" do
      storage_item = storage_item_fixture()
      assert {:ok, %StorageItem{}} = Storage.delete_storage_item(storage_item)
      assert_raise Ecto.NoResultsError, fn -> Storage.get_storage_item!(storage_item.id) end
    end

    test "change_storage_item/1 returns a storage_item changeset" do
      storage_item = storage_item_fixture()
      assert %Ecto.Changeset{} = Storage.change_storage_item(storage_item)
    end
  end

  describe "storage_access_logs" do
    alias WraftDoc.Storages.AccessLog

    import WraftDoc.StorageFixtures

    @invalid_attrs %{
      success: nil,
      metadata: nil,
      action: nil,
      session_id: nil,
      ip_address: nil,
      user_agent: nil
    }

    test "list_storage_access_logs/0 returns all storage_access_logs" do
      access_log = access_log_fixture()
      assert Storages.list_storage_access_logs() == [access_log]
    end

    test "get_access_log!/1 returns the access_log with given id" do
      access_log = access_log_fixture()
      assert Storages.get_access_log!(access_log.id) == access_log
    end

    test "create_access_log/1 with valid data creates a access_log" do
      valid_attrs = %{
        success: true,
        metadata: %{},
        action: "some action",
        session_id: "some session_id",
        ip_address: "some ip_address",
        user_agent: "some user_agent"
      }

      assert {:ok, %AccessLog{} = access_log} = Storages.create_access_log(valid_attrs)
      assert access_log.success == true
      assert access_log.metadata == %{}
      assert access_log.action == "some action"
      assert access_log.session_id == "some session_id"
      assert access_log.ip_address == "some ip_address"
      assert access_log.user_agent == "some user_agent"
    end

    test "create_access_log/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Storages.create_access_log(@invalid_attrs)
    end

    test "update_access_log/2 with valid data updates the access_log" do
      access_log = access_log_fixture()

      update_attrs = %{
        success: false,
        metadata: %{},
        action: "some updated action",
        session_id: "some updated session_id",
        ip_address: "some updated ip_address",
        user_agent: "some updated user_agent"
      }

      assert {:ok, %AccessLog{} = access_log} =
               Storages.update_access_log(access_log, update_attrs)

      assert access_log.success == false
      assert access_log.metadata == %{}
      assert access_log.action == "some updated action"
      assert access_log.session_id == "some updated session_id"
      assert access_log.ip_address == "some updated ip_address"
      assert access_log.user_agent == "some updated user_agent"
    end

    test "update_access_log/2 with invalid data returns error changeset" do
      access_log = access_log_fixture()
      assert {:error, %Ecto.Changeset{}} = Storages.update_access_log(access_log, @invalid_attrs)
      assert access_log == Storages.get_access_log!(access_log.id)
    end

    test "delete_access_log/1 deletes the access_log" do
      access_log = access_log_fixture()
      assert {:ok, %AccessLog{}} = Storages.delete_access_log(access_log)
      assert_raise Ecto.NoResultsError, fn -> Storages.get_access_log!(access_log.id) end
    end

    test "change_access_log/1 returns a access_log changeset" do
      access_log = access_log_fixture()
      assert %Ecto.Changeset{} = Storages.change_access_log(access_log)
    end
  end

  describe "storage_sync_jobs" do
    alias WraftDoc.Storages.SyncJob

    import WraftDoc.StorageFixtures

    @invalid_attrs %{
      status: nil,
      started_at: nil,
      job_type: nil,
      sync_source: nil,
      completed_at: nil,
      items_processed: nil,
      items_failed: nil,
      error_details: nil
    }

    test "list_storage_sync_jobs/0 returns all storage_sync_jobs" do
      sync_job = sync_job_fixture()
      assert Storages.list_storage_sync_jobs() == [sync_job]
    end

    test "get_sync_job!/1 returns the sync_job with given id" do
      sync_job = sync_job_fixture()
      assert Storages.get_sync_job!(sync_job.id) == sync_job
    end

    test "create_sync_job/1 with valid data creates a sync_job" do
      valid_attrs = %{
        status: "some status",
        started_at: ~U[2025-06-07 21:00:00Z],
        job_type: "some job_type",
        sync_source: "some sync_source",
        completed_at: ~U[2025-06-07 21:00:00Z],
        items_processed: 42,
        items_failed: 42,
        error_details: %{}
      }

      assert {:ok, %SyncJob{} = sync_job} = Storages.create_sync_job(valid_attrs)
      assert sync_job.status == "some status"
      assert sync_job.started_at == ~U[2025-06-07 21:00:00Z]
      assert sync_job.job_type == "some job_type"
      assert sync_job.sync_source == "some sync_source"
      assert sync_job.completed_at == ~U[2025-06-07 21:00:00Z]
      assert sync_job.items_processed == 42
      assert sync_job.items_failed == 42
      assert sync_job.error_details == %{}
    end

    test "create_sync_job/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Storages.create_sync_job(@invalid_attrs)
    end

    test "update_sync_job/2 with valid data updates the sync_job" do
      sync_job = sync_job_fixture()

      update_attrs = %{
        status: "some updated status",
        started_at: ~U[2025-06-08 21:00:00Z],
        job_type: "some updated job_type",
        sync_source: "some updated sync_source",
        completed_at: ~U[2025-06-08 21:00:00Z],
        items_processed: 43,
        items_failed: 43,
        error_details: %{}
      }

      assert {:ok, %SyncJob{} = sync_job} = Storages.update_sync_job(sync_job, update_attrs)
      assert sync_job.status == "some updated status"
      assert sync_job.started_at == ~U[2025-06-08 21:00:00Z]
      assert sync_job.job_type == "some updated job_type"
      assert sync_job.sync_source == "some updated sync_source"
      assert sync_job.completed_at == ~U[2025-06-08 21:00:00Z]
      assert sync_job.items_processed == 43
      assert sync_job.items_failed == 43
      assert sync_job.error_details == %{}
    end

    test "update_sync_job/2 with invalid data returns error changeset" do
      sync_job = sync_job_fixture()
      assert {:error, %Ecto.Changeset{}} = Storages.update_sync_job(sync_job, @invalid_attrs)
      assert sync_job == Storages.get_sync_job!(sync_job.id)
    end

    test "delete_sync_job/1 deletes the sync_job" do
      sync_job = sync_job_fixture()
      assert {:ok, %SyncJob{}} = Storages.delete_sync_job(sync_job)
      assert_raise Ecto.NoResultsError, fn -> Storages.get_sync_job!(sync_job.id) end
    end

    test "change_sync_job/1 returns a sync_job changeset" do
      sync_job = sync_job_fixture()
      assert %Ecto.Changeset{} = Storages.change_sync_job(sync_job)
    end
  end
end
