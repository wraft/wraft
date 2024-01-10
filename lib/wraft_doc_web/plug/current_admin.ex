defmodule WraftDocWeb.Plug.CurrentAdmin do
  @moduledoc """
  A plug that assigns the current admin details to the conn.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]

  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.Repo

  alias WraftDocWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    with %{"admin_id" => admin_id} <- get_session(conn),
         %InternalUser{} = user <- Repo.get(InternalUser, admin_id) do
      assign(conn, :admin_session, user)
    else
      _ ->
        conn
        |> put_flash(:info, "Please login to continue.")
        |> redirect(to: Routes.session_path(conn, :new))
        |> halt()
    end
  end
end
