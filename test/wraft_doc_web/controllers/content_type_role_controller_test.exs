defmodule WraftDocWeb.Api.V1.ContentTypeRoleControllerTest do
  @moduledoc """
  Test module for content type role controller test
  """
  use WraftDocWeb.ConnCase
  alias WraftDoc.Document.ContentTypeRole
  alias WraftDoc.Repo

  import WraftDoc.Factory

  @invalid_attrs %{content_type_id: nil, role_id: nil}

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

  test "delete content type role", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    content_type_role = insert(:content_type_role)
    insert(:membership, organisation: user.organisation)
    count_before = ContentTypeRole |> Repo.all() |> length()

    conn =
      delete(
        conn,
        Routes.v1_content_type_role_path(conn, :delete, content_type_role.id)
      )

    assert count_before - 1 == ContentTypeRole |> Repo.all() |> length()
    assert json_response(conn, 200)["uuid"] == content_type_role.id
  end

  test "create content with valid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    role = insert(:role)
    content_type = insert(:content_type)
    insert(:membership, organisation: user.organisation)

    params = %{
      role_id: role.id,
      content_type_id: content_type.id
    }

    count_before = ContentTypeRole |> Repo.all() |> length()

    conn =
      post(
        conn,
        Routes.v1_content_type_role_path(conn, :create, params)
      )

    assert count_before + 1 == ContentTypeRole |> Repo.all() |> length()
    assert json_response(conn, 200)["role"]["id"] == role.id
  end
end
