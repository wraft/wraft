defmodule StarterWeb.Api.V1.RegistrationController do
  @moduledoc """
  RegistrationController module handles the user's registration 
  process.
  """
  use StarterWeb, :controller
  import Ecto.Query, warn: false
  alias Starter.{User_management, User_management.User, Repo}
  require IEx
  action_fallback(StarterWeb.FallbackController)

  # User Registration
  def create(conn, params) do
    with {:ok, %User{} = user} <- User_management.user_registration(params) do
        conn
        |> put_status(:created)
        |> render("registerview.json", user: user)
    end
  end
end
