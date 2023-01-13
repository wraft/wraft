defmodule WraftDocWeb.CurrentUser do
  @moduledoc """
  This is a plug that stores the current user details in the
  conn based on the subject in the JWT token.
  """
  import Plug.Conn
  import Guardian.Plug
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Document.InstanceApprovalSystem
  alias WraftDoc.Repo

  alias WraftDocWeb.Guardian.AuthErrorHandler

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user_email = current_resource(conn)

    case Repo.get_by(User, email: current_user_email) do
      nil ->
        AuthErrorHandler.auth_error(conn, {:error, :no_user})

      user ->
        instances_to_approve = from(ias in InstanceApprovalSystem, where: ias.flag == false)

        user =
          Repo.preload(user, [
            :profile,
            :roles,
            instances_to_approve: instances_to_approve
          ])

        role_names = Enum.map(user.roles, fn x -> x.name end)
        user = Map.put(user, :role_names, role_names)
        assign(conn, :current_user, user)
    end
  end
end
