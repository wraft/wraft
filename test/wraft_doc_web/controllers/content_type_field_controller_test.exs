defmodule WraftDocWeb.Api.V1.ContentTypeFieldControllerTest do
  @moduledoc """
  Test module for content type field controller.
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory
  alias WraftDoc.{Document.ContentTypeField, Repo}

  test "delete content type field by given id", %{conn: conn} do
    user = conn.assigns.current_user

    content_type =
      insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

    content_type_field = insert(:content_type_field, content_type: content_type)
    count_before = ContentTypeField |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_content_type_field_path(conn, :delete, content_type_field.id))

    assert count_before - 1 == ContentTypeField |> Repo.all() |> length()

    assert json_response(conn, 200)["content_type"]["name"] ==
             content_type_field.content_type.name
  end

  test "error not found for user from another organisation", %{conn: conn} do
    content_type_field = insert(:content_type_field)
    conn = delete(conn, Routes.v1_content_type_field_path(conn, :delete, content_type_field.id))
    assert json_response(conn, 400)["errors"] == "The ContentTypeField id does not exist..!"
  end
end
