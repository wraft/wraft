defmodule WraftDocWeb.Api.V1.RegistrationController do
  use WraftDocWeb, :controller
  import Ecto.Query, warn: false

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Account, Account.User}

  @doc """
    New registration.
  """
  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    with %User{} = user <- Account.registration(params),
         {:ok, token, _claims} <-
           Account.authenticate(%{user: user, password: params["password"]}) do
      conn
      |> put_status(:created)
      |> render("create.json", user: user, token: token)
    end
  end
end
