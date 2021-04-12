defmodule WraftDocWeb.Plug.AdminCheck do
  @moduledoc """
  Plug to check if user has admin role.
  """
  import Plug.Conn

  alias WraftDoc.Account.User

  def init(_params) do
  end

  def call(conn, _params) do
    %User{role: %{name: role_name}} = conn.assigns[:current_user]

    case role_name do
      "admin" ->
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
