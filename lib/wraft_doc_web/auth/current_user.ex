defmodule WraftDocWeb.CurrentUser do
  @moduledoc """
  This is a plug that stores the current user details in the
  conn based on the subject in the JWT token.
  """
  import Plug.Conn
  import Guardian.Plug
  alias WraftDoc.{Account.User, Repo}
  alias WraftDocWeb.Guardian.AuthErrorHandler

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user_email = current_resource(conn)

    case Repo.get_by(User, email: current_user_email) do
      nil ->
        AuthErrorHandler.auth_error(conn, {:error, :no_user})

      user ->
        user = Repo.preload(user, [:profile, :roles, :organisation])

        role_names = user.roles |> Enum.map(fn x -> x.name end)
        user = user |> Map.put(:role_names, role_names)
        assign(conn, :current_user, user)
    end
  end
end
