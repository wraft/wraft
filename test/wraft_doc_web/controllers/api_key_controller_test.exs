defmodule WraftDocWeb.Api.V1.ApiKeyControllerTest do
  @moduledoc """
  Test module for API key controller
  """
  use WraftDocWeb.ConnCase, async: false
  @moduletag :controller

  alias WraftDoc.ApiKeys.ApiKey
  alias WraftDoc.Repo
  import WraftDoc.Factory

  @valid_attrs %{
    name: "Test API Key",
    rate_limit: 1000
  }

  @invalid_attrs %{
    name: nil
  }

  @update_attrs %{
    name: "Updated API Key",
    rate_limit: 2000
  }

  describe "index/2" do
    test "lists all API keys for user's organisation", %{conn: conn} do
      user = conn.assigns.current_user

      organisation = List.first(user.owned_organisations)

      _api_key_1 =
        insert(:api_key,
          user: user,
          organisation: organisation,
          created_by: user,
          name: "Key 1"
        )

      _api_key_2 =
        insert(:api_key,
          user: user,
          organisation: organisation,
          created_by: user,
          name: "Key 2"
        )

      other_org = insert(:organisation)

      other_user =
        insert(:user,
          email: "other_#{Base.encode16(:crypto.strong_rand_bytes(16))}@example.com",
          current_org_id: other_org.id,
          owned_organisations: [other_org]
        )

      _other_api_key =
        insert(:api_key,
          user: other_user,
          organisation: other_org,
          created_by: other_user,
          name: "Other Key"
        )

      conn = get(conn, Routes.v1_api_key_path(conn, :index))

      response = json_response(conn, 200)
      assert length(response["api_keys"]) == 2

      api_key_names = Enum.map(response["api_keys"], fn key -> key["name"] end)

      assert "Key 1" in api_key_names
      assert "Key 2" in api_key_names
      refute "Other Key" in api_key_names
    end

    test "returns empty list when no API keys exist", %{conn: conn} do
      conn = get(conn, Routes.v1_api_key_path(conn, :index))

      response = json_response(conn, 200)
      assert response["api_keys"] == []
      assert response["total_entries"] == 0
    end
  end

  describe "show/2" do
    test "shows an API key from user's organisation", %{conn: conn} do
      user = conn.assigns.current_user
      organisation = List.first(user.owned_organisations)

      api_key =
        insert(:api_key,
          organisation_id: organisation.id,
          user_id: user.id,
          created_by_id: user.id,
          name: "Test Key"
        )

      conn = get(conn, Routes.v1_api_key_path(conn, :show, api_key.id))

      response = json_response(conn, 200)
      assert response["id"] == api_key.id
      assert response["name"] == "Test Key"
      assert response["key_prefix"] != nil
      refute Map.has_key?(response, "key")
    end

    test "returns 404 for API key from different organisation", %{conn: conn} do
      other_org = insert(:organisation)
      other_user = insert(:user, current_org_id: other_org.id, owned_organisations: [other_org])

      api_key =
        insert(:api_key,
          organisation_id: other_org.id,
          user_id: other_user.id,
          created_by_id: other_user.id
        )

      conn = get(conn, Routes.v1_api_key_path(conn, :show, api_key.id))

      assert json_response(conn, 404) == "Not Found"
    end

    test "returns 404 for non-existent API key", %{conn: conn} do
      conn = get(conn, Routes.v1_api_key_path(conn, :show, Ecto.UUID.generate()))

      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "create/2" do
    test "creates API key with valid attributes", %{conn: conn} do
      _user = conn.assigns.current_user
      count_before = ApiKey |> Repo.all() |> length()

      conn = post(conn, Routes.v1_api_key_path(conn, :create), @valid_attrs)

      response = json_response(conn, 201)
      count_after = ApiKey |> Repo.all() |> length()

      assert count_after == count_before + 1
      assert response["name"] == "Test API Key"
      assert response["rate_limit"] == 1000
      assert response["is_active"] == true

      # The full key should be returned only on creation
      assert Map.has_key?(response, "key")
      assert String.starts_with?(response["key"], "wraft_")
    end

    test "creates API key with custom settings", %{conn: conn} do
      attrs = %{
        name: "Custom Key",
        rate_limit: 500,
        ip_whitelist: ["192.168.1.1"],
        metadata: %{integration: "salesforce"}
      }

      conn = post(conn, Routes.v1_api_key_path(conn, :create), attrs)

      response = json_response(conn, 201)
      assert response["name"] == "Custom Key"
      assert response["rate_limit"] == 500
      assert response["ip_whitelist"] == ["192.168.1.1"]
      assert response["metadata"]["integration"] == "salesforce"
    end

    test "returns error with invalid attributes", %{conn: conn} do
      count_before = ApiKey |> Repo.all() |> length()

      conn = post(conn, Routes.v1_api_key_path(conn, :create), @invalid_attrs)

      count_after = ApiKey |> Repo.all() |> length()
      assert count_after == count_before
      assert json_response(conn, 422)["errors"] != nil
    end

    test "returns error for duplicate name in organisation", %{conn: conn} do
      user = conn.assigns.current_user

      insert(:api_key,
        organisation_id: user.current_org_id,
        user_id: user.id,
        created_by_id: user.id,
        name: "Duplicate"
      )

      conn = post(conn, Routes.v1_api_key_path(conn, :create), %{name: "Duplicate"})

      assert json_response(conn, 422)["errors"] != nil
    end
  end

  describe "update/2" do
    test "updates API key with valid attributes", %{conn: conn} do
      user = conn.assigns.current_user

      api_key =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id,
          name: "Old Name"
        )

      conn = put(conn, Routes.v1_api_key_path(conn, :update, api_key.id), @update_attrs)

      response = json_response(conn, 200)
      assert response["name"] == "Updated API Key"
      assert response["rate_limit"] == 2000
    end

    test "does not return the key on update", %{conn: conn} do
      user = conn.assigns.current_user

      api_key =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id
        )

      conn = put(conn, Routes.v1_api_key_path(conn, :update, api_key.id), @update_attrs)

      response = json_response(conn, 200)
      refute Map.has_key?(response, "key")
    end

    test "returns error with invalid attributes", %{conn: conn} do
      user = conn.assigns.current_user

      api_key =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id
        )

      conn =
        put(conn, Routes.v1_api_key_path(conn, :update, api_key.id), %{rate_limit: -10})

      assert json_response(conn, 422)["errors"] != nil
    end

    test "returns 404 for API key from different organisation", %{conn: conn} do
      other_org = insert(:organisation)
      other_user = insert(:user, current_org_id: other_org.id, owned_organisations: [other_org])

      api_key =
        insert(:api_key,
          organisation_id: other_org.id,
          user_id: other_user.id,
          created_by_id: other_user.id
        )

      conn = put(conn, Routes.v1_api_key_path(conn, :update, api_key.id), @update_attrs)

      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "delete/2" do
    test "deletes an API key", %{conn: conn} do
      user = conn.assigns.current_user

      api_key =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id
        )

      count_before = ApiKey |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_api_key_path(conn, :delete, api_key.id))

      count_after = ApiKey |> Repo.all() |> length()
      assert response(conn, 204)
      assert count_after == count_before - 1
      assert Repo.get(ApiKey, api_key.id) == nil
    end

    test "returns 404 for API key from different organisation", %{conn: conn} do
      other_org = insert(:organisation)
      other_user = insert(:user, current_org_id: other_org.id, owned_organisations: [other_org])

      api_key =
        insert(:api_key,
          organisation_id: other_org.id,
          user_id: other_user.id,
          created_by_id: other_user.id
        )

      conn = delete(conn, Routes.v1_api_key_path(conn, :delete, api_key.id))

      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "toggle_status/2" do
    test "toggles API key from active to inactive", %{conn: conn} do
      user = conn.assigns.current_user
      organisation = List.first(user.owned_organisations)

      api_key =
        insert(:api_key,
          organisation_id: organisation.id,
          user_id: user.id,
          created_by_id: user.id,
          is_active: true
        )

      conn = patch(conn, Routes.v1_api_key_path(conn, :toggle_status, api_key.id))

      response = json_response(conn, 200)
      assert response["is_active"] == false
    end

    test "toggles API key from inactive to active", %{conn: conn} do
      user = conn.assigns.current_user
      organisation = List.first(user.owned_organisations)

      api_key =
        insert(:api_key,
          organisation_id: organisation.id,
          user_id: user.id,
          created_by_id: user.id,
          is_active: false
        )

      conn = patch(conn, Routes.v1_api_key_path(conn, :toggle_status, api_key.id))

      response = json_response(conn, 200)
      assert response["is_active"] == true
    end

    test "returns 404 for API key from different organisation", %{conn: conn} do
      other_org = insert(:organisation)

      other_user =
        insert(:user,
          email: "other_toggle_#{Base.encode16(:crypto.strong_rand_bytes(16))}@example.com",
          current_org_id: other_org.id,
          owned_organisations: [other_org]
        )

      api_key =
        insert(:api_key,
          organisation_id: other_org.id,
          user_id: other_user.id,
          created_by_id: other_user.id
        )

      conn = patch(conn, Routes.v1_api_key_path(conn, :toggle_status, api_key.id))

      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "API Key Authentication" do
    test "can access endpoint with valid API key instead of JWT", %{conn: conn} do
      user = conn.assigns.current_user

      {:ok, api_key} =
        %ApiKey{}
        |> ApiKey.create_changeset(%{
          name: "Auth Test Key",
          organisation_id: user.current_org_id,
          user_id: user.id
        })
        |> Repo.insert()

      api_conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> Plug.Conn.put_req_header("x-api-key", api_key.key)

      api_conn = get(api_conn, Routes.v1_api_key_path(api_conn, :index))

      response = json_response(api_conn, 200)
      assert Map.has_key?(response, "api_keys")
    end

    test "returns 401 with invalid API key", %{conn: _conn} do
      api_conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> Plug.Conn.put_req_header("x-api-key", "wraft_invalid_key")

      api_conn = get(api_conn, Routes.v1_api_key_path(api_conn, :index))

      assert json_response(api_conn, 401)
    end

    test "returns 401 with no authentication", %{conn: _conn} do
      # Create a new connection without any auth
      api_conn =
        Plug.Conn.put_req_header(Phoenix.ConnTest.build_conn(), "accept", "application/json")

      api_conn = get(api_conn, Routes.v1_api_key_path(api_conn, :index))

      # Should fail with 401 Unauthorized
      assert json_response(api_conn, 401)
    end
  end
end
