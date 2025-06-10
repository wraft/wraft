defmodule WraftDocWeb.AccessLogControllerTest do
  use WraftDocWeb.ConnCase

  import WraftDoc.StorageFixtures

  alias WraftDoc.Storage.AccessLog

  @create_attrs %{
    success: true,
    metadata: %{},
    action: "some action",
    session_id: "some session_id",
    ip_address: "some ip_address",
    user_agent: "some user_agent"
  }
  @update_attrs %{
    success: false,
    metadata: %{},
    action: "some updated action",
    session_id: "some updated session_id",
    ip_address: "some updated ip_address",
    user_agent: "some updated user_agent"
  }
  @invalid_attrs %{success: nil, metadata: nil, action: nil, session_id: nil, ip_address: nil, user_agent: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all storage_access_logs", %{conn: conn} do
      conn = get(conn, ~p"/api/storage_access_logs")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create access_log" do
    test "renders access_log when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/storage_access_logs", access_log: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/storage_access_logs/#{id}")

      assert %{
               "id" => ^id,
               "action" => "some action",
               "ip_address" => "some ip_address",
               "metadata" => %{},
               "session_id" => "some session_id",
               "success" => true,
               "user_agent" => "some user_agent"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/storage_access_logs", access_log: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update access_log" do
    setup [:create_access_log]

    test "renders access_log when data is valid", %{conn: conn, access_log: %AccessLog{id: id} = access_log} do
      conn = put(conn, ~p"/api/storage_access_logs/#{access_log}", access_log: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/storage_access_logs/#{id}")

      assert %{
               "id" => ^id,
               "action" => "some updated action",
               "ip_address" => "some updated ip_address",
               "metadata" => %{},
               "session_id" => "some updated session_id",
               "success" => false,
               "user_agent" => "some updated user_agent"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, access_log: access_log} do
      conn = put(conn, ~p"/api/storage_access_logs/#{access_log}", access_log: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete access_log" do
    setup [:create_access_log]

    test "deletes chosen access_log", %{conn: conn, access_log: access_log} do
      conn = delete(conn, ~p"/api/storage_access_logs/#{access_log}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/storage_access_logs/#{access_log}")
      end
    end
  end

  defp create_access_log(_) do
    access_log = access_log_fixture()
    %{access_log: access_log}
  end
end
