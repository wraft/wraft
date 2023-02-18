defmodule WraftDocWeb.Plug.Authorized do
  @moduledoc """
  Checks if the user has permissions to perform an action.
  If the user has superadmin role, we assume they have access to everything.
  If the action doesnt have a permission listed in the controller, we assume
  every user has acces to it.
  """
  import Plug.Conn
  alias WraftDoc.Account.User
  @superadmin_role "superadmin"

  def init(opts), do: opts

  def call(%Plug.Conn{private: %{phoenix_action: action}} = conn, opts) do
    case Keyword.get(opts, action) do
      nil ->
        conn

      required_permission ->
        %User{permissions: permissions, role_names: role_names} = conn.assigns.current_user

        if @superadmin_role in role_names do
          conn
        else
          check_permission(conn, required_permission, permissions)
        end
    end
  end

  # Private
  defp check_permission(conn, required_permission, users_permissions) do
    case required_permission in users_permissions do
      true ->
        conn

      false ->
        body = Jason.encode!(%{errors: "Unauthorized access.!"})

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, body)
        |> halt()
    end
  end
end
