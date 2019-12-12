defmodule ExStarterWeb.Api.V1.ProfileController do
  use ExStarterWeb, :controller
  import Ecto.Query, warn: false
  alias ExStarter.{ProfileManagement, ProfileManagement.Profile}
  action_fallback(ExStarterWeb.FallbackController)
  require IEx
  # Profile Update
  def update(conn, params) do
    with %Profile{} = profile <- ProfileManagement.update_profile(conn, params) do
      conn
      |> render("profile.json", profile: profile)
    end
  end
end
