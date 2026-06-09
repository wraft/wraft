defmodule WraftDocWeb.Plug.CurrentAdmin do
  @moduledoc """
  A plug that assigns the current admin details to the conn.

  Delegates the full session gate (existence, deactivation, expiry, epoch
  revocation) to `WraftDoc.InternalUsers.fetch_active_admin/1`.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]

  alias WraftDoc.InternalUsers

  alias WraftDocWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    case InternalUsers.fetch_active_admin(get_session(conn)) do
      {:ok, admin} ->
        assign(conn, :admin_session, admin)

      :error ->
        conn
        |> put_flash(:info, "Please login to continue.")
        |> redirect(to: Routes.session_path(conn, :new))
        |> halt()
    end
  end
end
