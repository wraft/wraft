defmodule WraftDocWeb.CurrentUser do
  @moduledoc """
  This is a plug that stores the current user details in the
  conn based on the subject in the JWT token.
  """
  import Plug.Conn
  import Guardian.Plug
  alias WraftDoc.{Repo, Account.User}

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user_email = current_resource(conn)
    current_user = Repo.get_by(User, email: current_user_email) |> Repo.preload([:profile, :role])
    assign(conn, :current_user, current_user)
  end
end