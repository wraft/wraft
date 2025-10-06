defmodule WraftDocWeb.Api.V1.StorageItemsControllerTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory


  setup %{conn: conn} do
    user = insert(:user_with_organisation)
    organisation = List.first(user.owned_organisations)
    user = %{user | current_org_id: organisation.id}

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> assign(:current_user, user)

    {:ok, conn: conn, user: user, organisation: organisation}
  end

  describe "index" do
    test "lists root storage items when no parameters provided", %{
      conn: conn
    } do
      conn = get(conn, "/api/v1/storage/assets")

      assert %{
               "data" => [],
               "meta" => %{
                 "count" => 0,
                 "timestamp" => _
               }
             } = json_response(conn, 200)
    end

    test "returns error for invalid folder_id UUID", %{conn: conn} do
      conn = get(conn, "/api/v1/storage/assets?folder_id=invalid-uuid")

      assert %{"error" => "Invalid UUID format for folder_id"} = json_response(conn, 400)
    end

    test "returns error for non-existent folder", %{conn: conn} do
      folder_id = Ecto.UUID.generate()
      conn = get(conn, "/api/v1/storage/assets?folder_id=#{folder_id}")

      assert %{"error" => "Folder not found"} = json_response(conn, 404)
    end

    test "respects pagination parameters", %{conn: conn} do
      conn = get(conn, "/api/v1/storage/assets?limit=50&offset=10")

      assert %{
               "data" => [],
               "meta" => %{
                 "count" => 0,
                 "timestamp" => _
               }
             } = json_response(conn, 200)
    end
  end

  describe "show" do
    test "returns error for non-existent storage item", %{conn: conn} do
      item_id = Ecto.UUID.generate()
      conn = get(conn, "/api/v1/storage/assets/#{item_id}")

      assert %{"error" => "Storage item not found"} = json_response(conn, 404)
    end
  end

  describe "search" do
    test "returns error for short search term", %{conn: conn} do
      conn = get(conn, "/api/v1/storage/assets/search?q=a")

      assert %{"error" => "Search term must be at least 2 characters"} = json_response(conn, 400)
    end

    test "returns empty results for valid search term", %{conn: conn} do
      conn = get(conn, "/api/v1/storage/assets/search?q=test")

      assert %{
               "data" => [],
               "meta" => %{
                 "count" => 0,
                 "timestamp" => _
               }
             } = json_response(conn, 200)
    end

    test "respects type filter parameter", %{conn: conn} do
      conn = get(conn, "/api/v1/storage/assets/search?q=test&type=files")

      assert %{
               "data" => [],
               "meta" => %{
                 "count" => 0,
                 "timestamp" => _
               }
             } = json_response(conn, 200)
    end
  end

  describe "stats" do
    test "returns root folder statistics", %{conn: conn} do
      conn = get(conn, "/api/v1/storage/assets/stats")

      assert %{
               "data" => %{
                 "total_count" => 0,
                 "folder_count" => 0,
                 "file_count" => 0,
                 "total_size" => 0
               }
             } = json_response(conn, 200)
    end

    test "returns error for invalid parent_id UUID", %{conn: conn} do
      conn = get(conn, "/api/v1/storage/assets/stats?parent_id=invalid-uuid")

      assert %{"error" => "Invalid UUID format for parent_id"} = json_response(conn, 400)
    end
  end

  describe "breadcrumbs" do
    test "returns error for invalid UUID", %{conn: conn} do
      conn = get(conn, "/api/v1/storage/assets/invalid-uuid/breadcrumbs")

      assert %{"error" => "Invalid UUID format for id"} = json_response(conn, 400)
    end

    test "returns empty breadcrumbs for non-existent item", %{conn: conn} do
      item_id = Ecto.UUID.generate()
      conn = get(conn, "/api/v1/storage/assets/#{item_id}/breadcrumbs")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end
end
