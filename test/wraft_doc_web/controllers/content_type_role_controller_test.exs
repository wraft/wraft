defmodule WraftDocWeb.Api.V1.ContentTypeRoleControllerTest do
  @moduledoc """
  Test module for content type role controller test
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  alias WraftDoc.Document.ContentTypeRole
  alias WraftDoc.Repo

  import WraftDoc.Factory

  test "delete content type role", %{conn: conn} do
    content_type_role = insert(:content_type_role)
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
    role = insert(:role)
    content_type = insert(:content_type)

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
