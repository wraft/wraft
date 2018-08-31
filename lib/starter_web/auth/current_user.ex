defmodule StarterWeb.CurrentUser do
    import Plug.Conn
    import Guardian.Plug
    import Ecto.Query
    alias Starter.Repo
    alias Starter.User_management.User

def init(opts), do: opts
    def call(conn, _opts) do
        current_user_email = current_resource(conn)
        current_user = Repo.get_by(User, email: current_user_email)
        assign(conn, :current_user, current_user)
    end
end