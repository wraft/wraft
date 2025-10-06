defmodule WraftDocWeb.RepositoryControllerTest do
  use WraftDocWeb.ConnCase

  import WraftDoc.StorageFixtures

  alias WraftDoc.Storages.Repository

  @create_attrs %{
    name: "some name",
    status: "some status",
    description: "some description",
    storage_limit: 42,
    current_storage_used: 42,
    item_count: 42
  }
  @update_attrs %{
    name: "some updated name",
    status: "some updated status",
    description: "some updated description",
    storage_limit: 43,
    current_storage_used: 43,
    item_count: 43
  }
  @invalid_attrs %{
    name: nil,
    status: nil,
    description: nil,
    storage_limit: nil,
    current_storage_used: nil,
    item_count: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all repositories", %{conn: conn} do
      conn = get(conn, "/api/repositories")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create repository" do
    test "renders repository when data is valid", %{conn: conn} do
      conn = post(conn, "/api/repositories", repository: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, "/api/repositories/#{id}")

      assert %{
               "id" => ^id,
               "current_storage_used" => 42,
               "description" => "some description",
               "item_count" => 42,
               "name" => "some name",
               "status" => "some status",
               "storage_limit" => 42
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, "/api/repositories", repository: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update repository" do
    setup [:create_repository]

    test "renders repository when data is valid", %{
      conn: conn,
      repository: %Repository{id: id} = repository
    } do
      conn = put(conn, "/api/repositories/#{repository}", repository: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, "/api/repositories/#{id}")

      assert %{
               "id" => ^id,
               "current_storage_used" => 43,
               "description" => "some updated description",
               "item_count" => 43,
               "name" => "some updated name",
               "status" => "some updated status",
               "storage_limit" => 43
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, repository: repository} do
      conn = put(conn, "/api/repositories/#{repository}", repository: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete repository" do
    setup [:create_repository]

    test "deletes chosen repository", %{conn: conn, repository: repository} do
      conn = delete(conn, "/api/repositories/#{repository}")
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, "/api/repositories/#{repository}")
      end)
    end
  end

  defp create_repository(_) do
    repository = repository_fixture()
    %{repository: repository}
  end
end
