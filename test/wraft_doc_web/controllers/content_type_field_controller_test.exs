defmodule WraftDocWeb.Api.V1.ContentTypeFieldControllerTest do
  @moduledoc """
  Test module for content type field controller.
  """
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.{Document.ContentTypeField, Repo}

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

  test "delete content type field by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)

    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    content_type_field = insert(:content_type_field, content_type: content_type)
    count_before = ContentTypeField |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_content_type_field_path(conn, :delete, content_type_field.uuid))
    assert count_before - 1 == ContentTypeField |> Repo.all() |> length()

    assert json_response(conn, 200)["content_type"]["name"] ==
             content_type_field.content_type.name
  end

  test "error not found for user from another organisation", %{conn: conn} do
    user = conn.assigns[:current_user]
    insert(:membership, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    user = insert(:user)
    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    content_type_field = insert(:content_type_field, content_type: content_type)
    conn = delete(conn, Routes.v1_content_type_field_path(conn, :delete, content_type_field.uuid))
    assert json_response(conn, 404) == "Not Found"
  end
end
