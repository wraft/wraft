defmodule WraftDocWeb.Plug.SuperAdminCheck do
  @moduledoc """
  Plug to check if user has admin role.
  """
  import Plug.Conn

  def init(_params) do
  end

  def call(conn, _params) do
    current_user = conn.assigns.current_user

    case Enum.member?(current_user.role_names, "superadmin") do
      true ->
        conn

      _ ->
        body = Jason.encode!(%{errors: "You are not authorized for this action.!"})

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, body)
        |> halt()
    end
  end
end
