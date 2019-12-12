defmodule ExStarterWeb.CurrentUser do
  @moduledoc """
  This is a plug that stores the current user details in the 
  conn based on the subject in the JWT token.
  """
  import Plug.Conn
  import Guardian.Plug
  import Ecto.Query
  alias ExStarter.Repo
  alias ExStarter.UserManagement.User

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user_email = current_resource(conn)
    current_user = Repo.get_by(User, email: current_user_email)
    assign(conn, :current_user, current_user)
  end
end
