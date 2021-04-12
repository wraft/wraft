defmodule WraftDocWeb.Plug.AdminAuthenticate do
  @moduledoc """
  This is a plug that stores current admin user details in a aplug in Conn.
  """
  import Plug.Conn
  alias WraftDoc.{Repo, Account.User, Account.Role}
  import Ecto.Query
  alias WraftDocWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    with %{"admin_id" => admin_id} <- get_session(conn),
         %User{role: %{name: "admin"}} = user <- get_admin(admin_id) do
      assign(conn, :current_user, user)
    else
      _ ->
        no_session(conn)
    end
  end

  defp no_session(conn) do
    conn
    |> Phoenix.Controller.redirect(to: Routes.session_path(conn, :new))
    |> halt()
  end

  defp get_admin(<<_::288>> = id) do
    from(u in User,
      where: u.uuid == ^id,
      join: r in Role,
      on: u.role_id == r.id,
      where: r.name == "admin",
      preload: :role
    )
    |> Repo.one()
  end
end
