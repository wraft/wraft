defmodule WraftDocWeb.Api.V1.ContentTypeRoleControllerTest do
  @moduledoc """
  Test module for content type role controller test
  """
  use WraftDocWeb.ConnCase
  alias WraftDoc.Document.ContentTypeRole
  alias WraftDoc.Repo

  import WraftDoc.Factory

  @valid_attrs %{
    "name" => "admin"
  }

  @invalid_attrs %{
    "one" => "123"
  }

  test "show all the content type role", %{conn: conn} do
    content_type = insert(:content_type)

    # conn =
    # build_conn()
    # |> put_req_header("authorization", "Bearer #{conn.assigns.token}")

    conn = get(conn, Routes.v1_content_type_role_path(conn, :show, content_type.uuid))
    assert json_response(conn, 200)["name"] == content_type.name
  end

  # test "error not found for id which does not exist", %{conn: conn} do

  #   conn = get(conn, Routes.v1_content_type_role_path(conn, :show, Ecto.UUID.generate()))
  #   assert json_response(conn, 404) == "Not Found"
  # end
end
