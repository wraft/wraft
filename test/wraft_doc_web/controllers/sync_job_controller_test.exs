defmodule WraftDocWeb.SyncJobControllerTest do
  use WraftDocWeb.ConnCase

  import WraftDoc.StorageFixtures

  alias WraftDoc.Storage.SyncJob

  @create_attrs %{
    status: "some status",
    started_at: ~U[2025-06-07 21:00:00Z],
    job_type: "some job_type",
    sync_source: "some sync_source",
    completed_at: ~U[2025-06-07 21:00:00Z],
    items_processed: 42,
    items_failed: 42,
    error_details: %{}
  }
  @update_attrs %{
    status: "some updated status",
    started_at: ~U[2025-06-08 21:00:00Z],
    job_type: "some updated job_type",
    sync_source: "some updated sync_source",
    completed_at: ~U[2025-06-08 21:00:00Z],
    items_processed: 43,
    items_failed: 43,
    error_details: %{}
  }
  @invalid_attrs %{status: nil, started_at: nil, job_type: nil, sync_source: nil, completed_at: nil, items_processed: nil, items_failed: nil, error_details: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all storage_sync_jobs", %{conn: conn} do
      conn = get(conn, ~p"/api/storage_sync_jobs")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create sync_job" do
    test "renders sync_job when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/storage_sync_jobs", sync_job: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/storage_sync_jobs/#{id}")

      assert %{
               "id" => ^id,
               "completed_at" => "2025-06-07T21:00:00Z",
               "error_details" => %{},
               "items_failed" => 42,
               "items_processed" => 42,
               "job_type" => "some job_type",
               "started_at" => "2025-06-07T21:00:00Z",
               "status" => "some status",
               "sync_source" => "some sync_source"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/storage_sync_jobs", sync_job: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update sync_job" do
    setup [:create_sync_job]

    test "renders sync_job when data is valid", %{conn: conn, sync_job: %SyncJob{id: id} = sync_job} do
      conn = put(conn, ~p"/api/storage_sync_jobs/#{sync_job}", sync_job: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/storage_sync_jobs/#{id}")

      assert %{
               "id" => ^id,
               "completed_at" => "2025-06-08T21:00:00Z",
               "error_details" => %{},
               "items_failed" => 43,
               "items_processed" => 43,
               "job_type" => "some updated job_type",
               "started_at" => "2025-06-08T21:00:00Z",
               "status" => "some updated status",
               "sync_source" => "some updated sync_source"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, sync_job: sync_job} do
      conn = put(conn, ~p"/api/storage_sync_jobs/#{sync_job}", sync_job: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete sync_job" do
    setup [:create_sync_job]

    test "deletes chosen sync_job", %{conn: conn, sync_job: sync_job} do
      conn = delete(conn, ~p"/api/storage_sync_jobs/#{sync_job}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/storage_sync_jobs/#{sync_job}")
      end
    end
  end

  defp create_sync_job(_) do
    sync_job = sync_job_fixture()
    %{sync_job: sync_job}
  end
end
