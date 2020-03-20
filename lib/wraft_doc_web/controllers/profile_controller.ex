defmodule WraftDocWeb.Api.V1.ProfileController do
  use WraftDocWeb, :controller
  plug(WraftDocWeb.Plug.Authorized)
  import Ecto.Query, warn: false
  alias WraftDoc.{Account, Account.Profile}
  action_fallback(WraftDocWeb.FallbackController)

  # Profile Update
  def update(conn, params) do
    with %Profile{} = profile <- Account.update_profile(conn, params) do
      conn
      |> render("profile.json", profile: profile)
    end
  end
end
