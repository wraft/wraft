defmodule WraftDocWeb.Plug.AdminAuthenticate do
  @moduledoc """
  This is a plug that stores current admin user details in a aplug in Conn.
  """
  import Plug.Conn
  alias WraftDoc.{Account.Role, Account.User, Account.UserRole, Repo}
  import Ecto.Query
  alias WraftDocWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    with %{"admin_id" => admin_id} <- get_session(conn),
         %User{} = user <- get_admin(admin_id) do
      user = Repo.preload(user, [:profile, :roles])
      role_names = Enum.map(user.roles, fn x -> x.name end)
      user = Map.put(user, :role_names, role_names)
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
    query =
      from(u in User,
        where: u.id == ^id,
        join: ur in UserRole,
        on: ur.user_id == u.id,
        join: r in Role,
        on: ur.role_id == r.id,
        where: r.name == "super_admin"
      )

    Repo.one(query)
  end
end
