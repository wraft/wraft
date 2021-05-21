defmodule WraftDocWeb.Api.V1.OrganisationRoleControllerTest do
  @moduledoc """
  Test module for role controller test
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  alias WraftDoc.Account.Role
  alias WraftDoc.Repo
  import WraftDoc.Factory

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

  test "show all the roles for the organisation", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    organisation = insert(:organisation)
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)

    conn = get(conn, Routes.v1_organisation_role_path(conn, :show, organisation.id))
    assert json_response(conn, 200)["id"] == organisation.id
  end

  test "returns not exist error for id does not exist", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    organisation = insert(:organisation)
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)

    conn = get(conn, Routes.v1_organisation_role_path(conn, :show, Ecto.UUID.autogenerate()))
    assert json_response(conn, 400)["errors"] == "The id does not exist..!"
  end

  test "delete particular role for the organisation", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    role = insert(:role)
    organisation = insert(:organisation)
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)

    count_before = Role |> Repo.all() |> length()

    conn =
      delete(
        conn,
        Routes.v1_organisation_role_path(
          conn,
          :delete_organisation_role,
          organisation.id,
          role.id
        )
      )

    assert count_before - 1 == Role |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == role.name
  end
end
