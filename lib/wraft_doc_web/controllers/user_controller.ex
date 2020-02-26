defmodule WraftDocWeb.Api.V1.UserController do
  @moduledoc """
  UserController module handles all the processes user's requested
  by the user.
  """
  use WraftDocWeb, :controller
  import Ecto.Query, warn: false
  alias WraftDoc.{Account, Account.User}

  action_fallback(WraftDocWeb.FallbackController)

  @doc """
  User Login.
  """
  def signin(conn, params) do
    with %User{} = user <- Account.find(params["email"]),
         {:ok, token, _claims} <-
           Account.authenticate(%{user: user, password: params["password"]}) do
      conn
      |> render("sign-in.json", token: token, user: user)
    end
  end
end
