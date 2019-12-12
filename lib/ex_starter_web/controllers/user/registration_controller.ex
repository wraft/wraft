defmodule ExStarterWeb.Api.V1.RegistrationController do
  @moduledoc """
  RegistrationController module handles the user's registration 
  process.
  """
  use ExStarterWeb, :controller
  import Ecto.Query, warn: false
  alias ExStarter.{UserManagement, UserManagement.User, ProfileManagement.Profile, Repo}

  action_fallback(ExStarterWeb.FallbackController)

  # User Registration
  def create(conn, params) do
    with %Profile{} = profile <- UserManagement.user_registration(params) do
      conn
      |> put_status(:created)
      |> render("registerview.json", profile: profile)
    end
  end
end
