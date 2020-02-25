defmodule WraftDocWeb.Api.V1.UserController do
  @moduledoc """
  UserController module handles all the processes user's requested
  by the user.
  """
  use WraftDocWeb, :controller
  import Ecto.Query, warn: false
  alias WraftDoc.{Account, Account.User, Account.Profile}

  action_fallback(WraftDocWeb.FallbackController)

  @doc """
  New registration.
  """
  def create(conn, params) do
    with %Profile{} = profile <- Account.user_registration(params) do
      conn
      |> put_status(:created)
      |> render("registerview.json", profile: profile)
    end
  end

  @doc """
  User Login.
  """
  def signin(conn, params) do
    with %User{} = user <- Account.find(params["email"]) do
      with {:ok, token, _claims} <-
             Account.authenticate(%{user: user, password: params["password"]}) do
        conn
        |> render("token.json", token: token, user: user)
      end
    end
  end
end
