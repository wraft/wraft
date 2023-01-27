defmodule WraftDocWeb.Api.V1.PermissionControllerTest do
  @moduledoc """
  Test module for permission controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller

  # import WraftDoc.Factory
  # alias WraftDoc.Authorization.Permission
  # alias WraftDoc.Repo

  # TODO Uncomment and fix the tests once RBAC is done succefully
  # test "create permissions by valid attrrs", %{conn: conn} do
  #   role = insert(:role)
  #   resource = insert(:resource)

  #   conn =
  #     build_conn()
  #     |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
  #     |> assign(:current_user, conn.assigns.current_user)

  #   count_before = Permission |> Repo.all() |> length()
  #   params = Map.merge(%{}, %{role_id: role.id, resource_id: resource.id})

  #   conn =
  #     conn
  #     |> post(Routes.v1_permission_path(conn, :create, params))
  #     |> doc(operation_id: "create_permission")

  #   assert count_before + 1 == Permission |> Repo.all() |> length()
  #   assert json_response(conn, 200)["#{resource.category}_#{resource.action}"] == [role.name]
  # end

  # @tag :skip
  # test "index lists permissions by current user", %{conn: conn} do
  #   a1 = insert(:permission)
  #   a2 = insert(:permission)

  #   conn =
  #     build_conn()
  #     |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
  #     |> assign(:current_user, conn.assigns.current_user)

  #   conn = get(conn, Routes.v1_permission_path(conn, :index))

  #   permissions =
  #     conn
  #     |> json_response(200)
  #     |> get_in(["permissions"])
  #     |> Enum.map(fn x -> Map.keys(x) end)
  #     |> List.flatten()

  #   assert List.to_string(permissions) =~
  #            to_string(a1.resource.category) <> "_" <> to_string(a1.resource.action)

  #   assert List.to_string(permissions) =~
  #            to_string(a2.resource.category) <> "_" <> to_string(a2.resource.action)
  # end

  # test "delete permission by given id", %{conn: conn} do
  #   conn =
  #     build_conn()
  #     |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
  #     |> assign(:current_user, conn.assigns.current_user)

  #   permission = insert(:permission)
  #   count_before = Permission |> Repo.all() |> length()

  #   conn = delete(conn, Routes.v1_permission_path(conn, :delete, permission.id))
  #   assert count_before - 1 == Permission |> Repo.all() |> length()
  #   assert json_response(conn, 200)["role_id"] == permission.role.id
  # end
end
