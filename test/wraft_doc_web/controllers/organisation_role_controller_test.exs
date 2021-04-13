defmodule WraftDocWeb.Api.V1.OrganisationRoleControllerTest do
  @moduledoc """
  Test module for role controller test
  """
  use WraftDocWeb.ConnCase
  alias WraftDoc.Account.Role
  alias WraftDoc.Repo
  import WraftDoc.Factory

  test "show all the roles for the organisation", %{conn: conn} do
    organisation = insert(:organisation)

    # conn =
    # build_conn()
    # |> put_req_header("authorization", "Bearer #{conn.assigns.token}")

   conn = get(conn, Routes.v1_organisation_role_path(conn, :show, organisation.uuid))
   assert json_response(conn, 200)["id"] == organisation.uuid
  end

  test "delete particular role for the organisation", %{conn: conn} do
    # conn =
    #   build_conn()
    #   |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
    #   |> assign(:current_user, conn.assigns.current_user)

    role = insert(:role)
    organisation = insert(:organisation)

    count_before = Role |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_organisation_role_path(conn, :delete_organisation_role, organisation.uuid, role.uuid))
    assert count_before - 1 == Role |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == role.name
  end
end
