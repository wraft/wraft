defmodule WraftDocWeb.StorageAssetControllerTest do
  use WraftDocWeb.ConnCase

  import WraftDoc.StorageFixtures

  alias WraftDoc.Storages.StorageAsset

  @create_attrs %{
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
  @update_attrs %{
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

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all storage_assets", %{conn: conn} do
      conn = get(conn, "/api/storage_assets")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create storage_asset" do
    test "renders storage_asset when data is valid", %{conn: conn} do
      conn = post(conn, "/api/storage_assets", storage_asset: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, "/api/storage_assets/#{id}")

      assert %{
               "id" => ^id,
               "checksum_sha256" => "some checksum_sha256",
               "compression_type" => "some compression_type",
               "encryption_key_id" => "some encryption_key_id",
               "file_size" => 42,
               "mime_type" => "some mime_type",
               "preview_path" => "some preview_path",
               "processing_status" => "some processing_status",
               "storage_backend" => "some storage_backend",
               "storage_key" => "some storage_key",
               "thumbnail_path" => "some thumbnail_path",
               "upload_completed_at" => "2025-06-07T20:42:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, "/api/storage_assets", storage_asset: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update storage_asset" do
    setup [:create_storage_asset]

    test "renders storage_asset when data is valid", %{
      conn: conn,
      storage_asset: %StorageAsset{id: id} = storage_asset
    } do
      conn = put(conn, "/api/storage_assets/#{storage_asset}", storage_asset: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, "/api/storage_assets/#{id}")

      assert %{
               "id" => ^id,
               "checksum_sha256" => "some updated checksum_sha256",
               "compression_type" => "some updated compression_type",
               "encryption_key_id" => "some updated encryption_key_id",
               "file_size" => 43,
               "mime_type" => "some updated mime_type",
               "preview_path" => "some updated preview_path",
               "processing_status" => "some updated processing_status",
               "storage_backend" => "some updated storage_backend",
               "storage_key" => "some updated storage_key",
               "thumbnail_path" => "some updated thumbnail_path",
               "upload_completed_at" => "2025-06-08T20:42:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, storage_asset: storage_asset} do
      conn = put(conn, "/api/storage_assets/#{storage_asset}", storage_asset: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete storage_asset" do
    setup [:create_storage_asset]

    test "deletes chosen storage_asset", %{conn: conn, storage_asset: storage_asset} do
      conn = delete(conn, "/api/storage_assets/#{storage_asset}")
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, "/api/storage_assets/#{storage_asset}")
      end)
    end
  end

  defp create_storage_asset(_) do
    storage_asset = storage_asset_fixture()
    %{storage_asset: storage_asset}
  end
end
