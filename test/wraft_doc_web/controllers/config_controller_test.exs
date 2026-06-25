defmodule WraftDocWeb.Api.V1.ConfigControllerTest do
  @moduledoc false
  use WraftDocWeb.ConnCase, async: true
  @moduletag :controller

  describe "GET /api/v1/config" do
    test "is reachable without authentication and returns a boolean self_hosted flag" do
      conn = get(build_conn(), "/api/v1/config")

      assert %{"self_hosted" => self_hosted} = json_response(conn, 200)
      assert is_boolean(self_hosted)
    end

    test "reflects the configured deployment mode" do
      conn = get(build_conn(), "/api/v1/config")

      expected = WraftDoc.Enterprise.self_hosted?()
      assert %{"self_hosted" => ^expected} = json_response(conn, 200)
    end
  end
end
