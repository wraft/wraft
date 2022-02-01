defmodule WraftDocWeb.Plug.Authorized do
  @moduledoc false
  import Plug.Conn
  import Ecto.Query
  alias WraftDoc.{Account.Role, Authorization.Permission, Authorization.Resource, Repo}

  def init(_params) do
  end

  def call(conn, _params) do
    category = conn.private[:phoenix_controller]

    action = conn.private[:phoenix_action]

    query = from(r in Resource, where: r.category == ^category and r.action == ^action)
    query |> Repo.one() |> check_permission(conn)
  end

  defp check_permission(%Resource{id: id}, conn) do
    %{roles: roles, role_names: role_names} =
      Repo.preload(conn.assigns[:current_user], roles: [permissions: [:resource]])

    resources = list_of_resources(roles, [])

    case(
      Enum.member?(role_names, "super_admin") ||
        Enum.member?(resources, id)
    ) do
      true ->
        conn

      _ ->
        body = Jason.encode!(%{errors: "You are not authorized for this action.!"})

        conn |> put_resp_content_type("application/json") |> send_resp(400, body) |> halt()
    end
  end

  defp check_permission(nil, conn) do
    conn
  end

  defp list_of_resources([%Role{permissions: permissions} | roles], resource_list) do
    rl = traverse_permission(permissions, [])
    resouce_list = resource_list |> List.insert_at(0, rl) |> List.flatten()
    list_of_resources(roles, resouce_list)
  end

  defp list_of_resources([], resource_list), do: resource_list

  defp list_of_resources(nil, rl), do: rl

  defp traverse_permission([%Permission{resource: %Resource{id: id}} | permissions], rl) do
    rl = List.insert_at(rl, 0, id)
    traverse_permission(permissions, rl)
  end

  defp traverse_permission([], rl), do: rl
  defp traverse_permission(nil, rl), do: rl
end
