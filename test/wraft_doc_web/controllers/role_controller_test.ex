defmodule WraftDocWeb.Api.V1.RoleControllerTest do
  @moduledoc """
  Test module for role controller test
  """
  use WraftDocWeb.ConnCase
  alias WraftDoc.Account.Role
  alias WraftDoc.Repo
  import WraftDoc.Factory
  alias WraftDoc.Document.ContentType

  test "show all the role with the content type", %{conn: conn} do
    role = insert(:role)

    # conn =
    # build_conn()
    # |> put_req_header("authorization", "Bearer #{conn.assigns.token}")

    conn = get(conn, Routes.v1_role_path(conn, :show, role.uuid))
    assert json_response(conn, 200)["name"] == role.name
  end
end
