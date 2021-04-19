defmodule WraftDocWeb.Api.V1.RoleControllerTest do
  @moduledoc """
  Test module for role controller test
  """
  use WraftDocWeb.ConnCase
  alias WraftDoc.Account.Role
  alias WraftDoc.Repo
  import WraftDoc.Factory
  alias WraftDoc.Document.ContentType

  setup %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(
        Routes.v1_user_path(conn, :signin, %{
          email: user.email,
          password: user.password
        })
      )

    conn = assign(conn, :current_user, user)

    {:ok, %{conn: conn}}
  end

  test "show all the role with the content type", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    role = insert(:role)
    insert(:membership, organisation: user.organisation)
    conn = get(conn, Routes.v1_role_path(conn, :show, role.uuid))
    assert json_response(conn, 200)["name"] == role.name
  end
end
