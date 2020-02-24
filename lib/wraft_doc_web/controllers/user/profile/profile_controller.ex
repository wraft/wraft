defmodule WraftDocWeb.Api.V1.ProfileController do
  use WraftDocWeb, :controller
  import Ecto.Query, warn: false
  alias WraftDoc.{ProfileManagement, ProfileManagement.Profile}
  action_fallback(WraftDocWeb.FallbackController)
  require IEx
  # Profile Update
  def update(conn, params) do
    with %Profile{} = profile <- ProfileManagement.update_profile(conn, params) do
      conn
      |> render("profile.json", profile: profile)
    end
  end
end
