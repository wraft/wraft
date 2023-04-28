defmodule WraftDocWeb.Api.V1.PermissionControllerTest do
  @moduledoc """
  Test module for permission controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller

  @resources [
    "Approval System",
    "Asset",
    "Block",
    "Block Template",
    "Collection Form",
    "Collection Form Field",
    "Comment",
    "Content Type",
    "Content Type Field",
    "Content Type Role",
    "Data Template",
    "Engine",
    "Field Type",
    "Flow",
    "Instance",
    "Instance Approval System",
    "Layout",
    "Members",
    "Membership",
    "Organisation",
    "Organisation Field",
    "Payment",
    "Pipe Stage",
    "Pipeline",
    "Plan",
    "Role",
    "Role Group",
    "State",
    "Theme",
    "Trigger History",
    "Vendor"
  ]

  setup do
    user = WraftDoc.Factory.insert(:user_with_personal_organisation)
    organisation = List.first(user.owned_organisations)
    WraftDoc.Factory.insert(:user_organisation, user: user, organisation: organisation)

    role = WraftDoc.Factory.insert(:role, organisation: organisation)
    WraftDoc.Factory.insert(:user_role, user: user, role: role)

    {:ok, token, _} =
      WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
      |> Plug.Conn.assign(:current_user, user)

    %{conn: conn}
  end

  describe "GET /permissions" do
    test "returns all the permissions grouped by resource", %{conn: conn} do
      conn = get(conn, Routes.v1_permission_path(conn, :index))
      json = json_response(conn, 200)

      %{resources: resources, permissions: permissions} =
        Enum.reduce(
          json,
          %{resources: [], permissions: []},
          fn {resource, permissions}, acc ->
            %{
              resources: [resource | acc.resources],
              permissions: create_permissions_data(permissions) ++ acc.permissions
            }
          end
        )

      assert Enum.sort(resources) == @resources
      assert all_permissions() == Enum.sort(permissions)
    end
  end

  describe "GET /resources" do
    test "returns all the resources", %{conn: conn} do
      conn = get(conn, Routes.v1_permission_path(conn, :resource_index))
      resources = json_response(conn, 200)

      assert Enum.sort(resources) == @resources
    end
  end

  # Private
  defp all_permissions do
    "priv/repo/data/rbac/permissions.csv"
    |> File.stream!()
    |> CSV.decode(headers: ["name", "resource", "action"])
    |> Enum.map(fn {:ok, permission} -> create_permissions_data(permission) end)
    |> Enum.sort()
  end

  defp create_permissions_data(permissions) when is_list(permissions) do
    Enum.map(permissions, &create_permissions_data(&1))
  end

  defp create_permissions_data(permission) when is_map(permission) do
    %{
      name: permission["name"],
      action: permission["action"]
    }
  end
end
