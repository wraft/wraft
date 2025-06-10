defmodule WraftDocWeb.StorageItemControllerTest do
  use WraftDocWeb.ConnCase

  import WraftDoc.StorageFixtures

  alias WraftDoc.Storage.StorageItem

  @create_attrs %{
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
  @update_attrs %{
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
  @invalid_attrs %{name: nil, size: nil, path: nil, metadata: nil, display_name: nil, item_type: nil, path_hash: nil, depth_level: nil, materialized_path: nil, mime_type: nil, file_extension: nil, checksum_sha256: nil, version_number: nil, is_current_version: nil, classification_level: nil, is_deleted: nil, deleted_at: nil, sync_source: nil, external_id: nil, external_metadata: nil, last_synced_at: nil, content_extracted: nil, thumbnail_generated: nil, download_count: nil, last_accessed_at: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all storage_items", %{conn: conn} do
      conn = get(conn, ~p"/api/storage_items")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create storage_item" do
    test "renders storage_item when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/storage_items", storage_item: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/storage_items/#{id}")

      assert %{
               "id" => ^id,
               "checksum_sha256" => "some checksum_sha256",
               "classification_level" => "some classification_level",
               "content_extracted" => true,
               "deleted_at" => "2025-06-07T20:46:00Z",
               "depth_level" => 42,
               "display_name" => "some display_name",
               "download_count" => 42,
               "external_id" => "some external_id",
               "external_metadata" => %{},
               "file_extension" => "some file_extension",
               "is_current_version" => true,
               "is_deleted" => true,
               "item_type" => "some item_type",
               "last_accessed_at" => "2025-06-07T20:46:00Z",
               "last_synced_at" => "2025-06-07T20:46:00Z",
               "materialized_path" => "some materialized_path",
               "metadata" => %{},
               "mime_type" => "some mime_type",
               "name" => "some name",
               "path" => "some path",
               "path_hash" => "some path_hash",
               "size" => 42,
               "sync_source" => "some sync_source",
               "thumbnail_generated" => true,
               "version_number" => "some version_number"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/storage_items", storage_item: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update storage_item" do
    setup [:create_storage_item]

    test "renders storage_item when data is valid", %{conn: conn, storage_item: %StorageItem{id: id} = storage_item} do
      conn = put(conn, ~p"/api/storage_items/#{storage_item}", storage_item: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/storage_items/#{id}")

      assert %{
               "id" => ^id,
               "checksum_sha256" => "some updated checksum_sha256",
               "classification_level" => "some updated classification_level",
               "content_extracted" => false,
               "deleted_at" => "2025-06-08T20:46:00Z",
               "depth_level" => 43,
               "display_name" => "some updated display_name",
               "download_count" => 43,
               "external_id" => "some updated external_id",
               "external_metadata" => %{},
               "file_extension" => "some updated file_extension",
               "is_current_version" => false,
               "is_deleted" => false,
               "item_type" => "some updated item_type",
               "last_accessed_at" => "2025-06-08T20:46:00Z",
               "last_synced_at" => "2025-06-08T20:46:00Z",
               "materialized_path" => "some updated materialized_path",
               "metadata" => %{},
               "mime_type" => "some updated mime_type",
               "name" => "some updated name",
               "path" => "some updated path",
               "path_hash" => "some updated path_hash",
               "size" => 43,
               "sync_source" => "some updated sync_source",
               "thumbnail_generated" => false,
               "version_number" => "some updated version_number"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, storage_item: storage_item} do
      conn = put(conn, ~p"/api/storage_items/#{storage_item}", storage_item: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete storage_item" do
    setup [:create_storage_item]

    test "deletes chosen storage_item", %{conn: conn, storage_item: storage_item} do
      conn = delete(conn, ~p"/api/storage_items/#{storage_item}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/storage_items/#{storage_item}")
      end
    end
  end

  defp create_storage_item(_) do
    storage_item = storage_item_fixture()
    %{storage_item: storage_item}
  end
end
