defmodule WraftDocWeb.Plug.AdminAuthenticate do
  @moduledoc """
  This is a plug that stores current admin user details in a aplug in Conn.
  """
  import Plug.Conn
  alias WraftDoc.{Repo, Account.User, Account.Role, Account.UserRole}
  import Ecto.Query
  alias WraftDocWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    with %{"admin_id" => admin_id} <- get_session(conn),
         %User{} = user <- get_admin(admin_id) do
      user = user |> Repo.preload([:profile, :roles])
      role_names = user.roles |> Enum.map(fn x -> x.name end)
      user = user |> Map.put(:role_names, role_names)
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
      join: ur in UserRole,
      on: ur.user_id == u.id,
      join: r in Role,
      on: ur.role_id == r.id,
      where: r.name == "super_admin"
    )
    |> Repo.one()
  end
end
