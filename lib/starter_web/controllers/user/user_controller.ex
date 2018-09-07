defmodule StarterWeb.Api.V1.UserController do
@moduledoc """
  UserController module handles all the processes user's requested
  by the user.  
  """
  use StarterWeb, :controller
  import Ecto.Query, warn: false
  alias Starter.{UserManagement, UserManagement.User, Repo}
  require IEx
  action_fallback(StarterWeb.FallbackController)

# User Login
    def signin(conn, params) do
        with %User{} = user <- UserManagement.find(params["email"]) do 
            with {:ok, token, _claims} <- UserManagement.authenticate(%{user: user, password: params["password"]}) do
                conn
                |> render("token.json", token: token, user: user)
            end
        end
    end
end