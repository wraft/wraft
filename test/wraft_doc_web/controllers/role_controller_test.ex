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

  test "delete particular role by giving particular content type id", %{conn: conn} do
    # conn =
    #   build_conn()
    #   |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
    #   |> assign(:current_user, conn.assigns.current_user)

    role = insert(:role)
    content_type = insert(:content_type)

    count_before = Role |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_role_path(conn, :delete_content_type_role, role.uuid, content_type.uuid))
    assert count_before - 1 == Role |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == role.name
  end
end
