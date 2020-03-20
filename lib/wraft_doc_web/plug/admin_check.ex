defmodule WraftDocWeb.Plug.AdminCheck do
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
        body = Poison.encode!(%{error: "You are not authorized for this action.!"})

        send_resp(conn, 400, body)
        |> halt()
    end
  end
end
