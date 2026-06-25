defmodule WraftDocWeb.Api.V1.AiFeatureFlagTest do
  @moduledoc """
  The `:ai_features` org flag must gate every AI controller
  (ModelController, PromptsController, AIToolController) at the API layer,
  not just in the frontend. Disabled orgs get 403 before the action runs.
  """
  use WraftDocWeb.ConnCase, async: false
  @moduletag :controller

  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.FeatureFlags
  alias WraftDoc.Repo

  defp current_org(conn) do
    Repo.get(Organisation, conn.assigns.current_user.current_org_id)
  end

  describe "ai_features disabled (default for new orgs)" do
    test "GET /ai/models is forbidden", %{conn: conn} do
      conn = get(conn, "/api/v1/ai/models")
      assert conn.status == 403
      assert response(conn, 403) =~ "ai_features"
    end

    test "GET /ai/models/providers is forbidden", %{conn: conn} do
      conn = get(conn, "/api/v1/ai/models/providers")
      assert conn.status == 403
    end

    test "GET /ai/prompts is forbidden", %{conn: conn} do
      conn = get(conn, "/api/v1/ai/prompts")
      assert conn.status == 403
    end

    test "POST /ai/generate is forbidden before the action runs", %{conn: conn} do
      conn = post(conn, "/api/v1/ai/generate", %{})
      assert conn.status == 403
    end
  end

  describe "ai_features enabled" do
    setup %{conn: conn} do
      {:ok, _} = FeatureFlags.enable(:ai_features, current_org(conn))
      :ok
    end

    test "GET /ai/models is allowed", %{conn: conn} do
      conn = get(conn, "/api/v1/ai/models")
      assert json_response(conn, 200)
    end

    test "GET /ai/models/providers is allowed", %{conn: conn} do
      conn = get(conn, "/api/v1/ai/models/providers")
      assert json_response(conn, 200)
    end

    test "GET /ai/prompts is allowed", %{conn: conn} do
      conn = get(conn, "/api/v1/ai/prompts")
      assert json_response(conn, 200)
    end
  end
end
